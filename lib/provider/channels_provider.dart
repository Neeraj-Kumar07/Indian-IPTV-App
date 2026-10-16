
// THIS FILE CONTAIN "lib/provider/channels_provider.dart" CODE


import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../model/channel.dart';
import '../model/stream_source.dart';

class ChannelsProvider with ChangeNotifier {
  static const streamsCatalogUrl =
      'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';

  // One ClearKey pair: "32 hex chars : 32 hex chars".
  static final RegExp _clearKeyPattern =
  RegExp(r'^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$');

  // Matches key="value" pairs inside an #EXTINF line, in any order.
  static final RegExp _attrPattern = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

  // Header names are stored in one canonical spelling, so "cookie" and
  // "Cookie" can never end up as two separate headers.
  static const Map<String, String> _canonicalHeaders = {
    'cookie': 'Cookie',
    'origin': 'Origin',
    'referer': 'Referer',
    'referrer': 'Referer',
    'user-agent': 'User-Agent',
  };

  void _putHeader(Map<String, String> headers, String key, String value,
      {bool overwrite = true}) {
    final k = key.trim();
    if (k.isEmpty) return;
    final name = _canonicalHeaders[k.toLowerCase()] ?? k;
    if (!overwrite && headers.containsKey(name)) return;
    headers[name] = value;
  }

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];

  // ------------------------------------------------------------
  // STREAM CATEGORIES (from the bundled data/streams.csv)
  // ------------------------------------------------------------

  Future<List<StreamSource>> fetchStreamSources() async {
    final fileText = await rootBundle.loadString('data/streams.csv');
    final sources = <StreamSource>[];

    for (final line in fileText.split('\n')) {
      final trimmed = line.trim();

      if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('name,')) {
        continue;
      }

      final commaIndex = trimmed.indexOf(',');
      if (commaIndex == -1) continue;

      final name = trimmed.substring(0, commaIndex).trim();
      final streamUrl = trimmed.substring(commaIndex + 1).trim();

      if (name.isNotEmpty && streamUrl.isNotEmpty) {
        sources.add(StreamSource(name: name, streamUrl: streamUrl));
      }
    }

    return sources;
  }

  // ------------------------------------------------------------
  // M3U PARSER (with DRM + header support)
  // ------------------------------------------------------------

  Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
    channels.clear();
    filteredChannels.clear();

    late final String fileText;

    if (!sourceUrl.startsWith('http')) {
      fileText = await rootBundle.loadString(sourceUrl);
    } else {
      final response = await http.get(Uri.parse(sourceUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to load M3U file: HTTP ${response.statusCode}');
      }

      fileText = utf8.decode(response.bodyBytes, allowMalformed: true);
    }

    // Values collected for the channel currently being parsed.
    String? name;
    String logoUrl = getDefaultLogoUrl();
    String? tvgId;
    String? groupTitle;
    String? licenseKey;
    String? licenseUrl;
    String? drmType;
    bool manifestIsDash = false;
    final headers = <String, String>{};

    void resetPending() {
      name = null;
      logoUrl = getDefaultLogoUrl();
      tvgId = null;
      groupTitle = null;
      licenseKey = null;
      licenseUrl = null;
      drmType = null;
      manifestIsDash = false;
      headers.clear();
    }

    for (final rawLine in fileText.split('\n')) {
      final line = rawLine.trim(); // also removes '\r' from Windows files
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final info = _parseExtinf(line);
        name = info.name;
        logoUrl = info.logo ?? getDefaultLogoUrl();
        tvgId = info.id;
        groupTitle = info.group;
      }
      // ---- DRM type: clearkey, com.widevine.alpha, ... ----
      else if (line.startsWith('#KODIPROP:inputstream.adaptive.license_type=')) {
        drmType = line.substring(line.indexOf('=') + 1).trim().toLowerCase();
      }
      // ---- DRM key: hex key(s), JWK json, or a license URL ----
      else if (line.startsWith('#KODIPROP:inputstream.adaptive.license_key=')) {
        final value = line.substring(line.indexOf('=') + 1).trim();

        if (value.startsWith('http://') || value.startsWith('https://')) {
          // Kodi may append "|Header=value|..." after the URL; keep the URL only.
          licenseUrl = value.split('|').first.trim();
        } else {
          final parsed = _parseLicenseKey(value);
          if (parsed != null) licenseKey = parsed;
        }
      }
      // ---- Manifest type hint ----
      else if (line.startsWith('#KODIPROP:inputstream.adaptive.manifest_type=')) {
        final value = line.substring(line.indexOf('=') + 1).trim().toLowerCase();
        manifestIsDash = value == 'mpd' || value == 'dash';
      }
      // ---- Headers: Kodi style "User-Agent=x&Referer=y" ----
      else if (line.startsWith('#KODIPROP:inputstream.adaptive.stream_headers=') ||
          line.startsWith('#KODIPROP:inputstream.adaptive.manifest_headers=')) {
        _parseHeaderString(line.substring(line.indexOf('=') + 1))
            .forEach((k, v) => _putHeader(headers, k, v));
      }
      // ---- Headers: VLC style ----
      else if (line.startsWith('#EXTVLCOPT:http-user-agent=')) {
        headers['User-Agent'] = line.substring(line.indexOf('=') + 1).trim();
      } else if (line.startsWith('#EXTVLCOPT:http-referrer=') ||
          line.startsWith('#EXTVLCOPT:http-referer=')) {
        headers['Referer'] = line.substring(line.indexOf('=') + 1).trim();
      } else if (line.startsWith('#EXTVLCOPT:http-origin=')) {
        headers['Origin'] = line.substring(line.indexOf('=') + 1).trim();
      }
      // ---- Headers: JSON style  #EXTHTTP:{"cookie":"..."} ----
      else if (line.startsWith('#EXTHTTP:')) {
        try {
          final decoded = jsonDecode(line.substring('#EXTHTTP:'.length));
          if (decoded is Map) {
            decoded.forEach(
                    (k, v) => _putHeader(headers, k.toString(), v.toString()));
          }
        } catch (_) {
          // ignore malformed JSON
        }
      }
      // ---- Any other comment / tag line ----
      else if (line.startsWith('#')) {
        continue;
      }
      // ---- Stream URL line: build the channel ----
      else {
        var streamUrl = line;

        // Some playlists append headers to the URL: url|User-Agent=x&Referer=y
        final pipeIndex = streamUrl.indexOf('|');
        if (pipeIndex != -1) {
          // Headers from the URL tail only fill gaps: they never replace a
          // header given by #EXTHTTP / #EXTVLCOPT (the tail is URL-decoded,
          // which can change a token cookie such as acl=%2f* into acl=/*).
          _parseHeaderString(streamUrl.substring(pipeIndex + 1))
              .forEach((k, v) => _putHeader(headers, k, v, overwrite: false));
          streamUrl = streamUrl.substring(0, pipeIndex).trim();
        }

        // "...index.m3u8?|cookie=..." leaves a dangling '?': drop it.
        if (streamUrl.endsWith('?')) {
          streamUrl = streamUrl.substring(0, streamUrl.length - 1);
        }

        if (name != null && streamUrl.isNotEmpty) {
          final lowerUrl = streamUrl.toLowerCase();
          final isDash = manifestIsDash ||
              lowerUrl.contains('.mpd') ||
              lowerUrl.contains('manifest_type=mpd');

          channels.add(Channel(
            name: name!,
            logoUrl: logoUrl,
            streamUrl: streamUrl,
            httpHeaders:
            headers.isEmpty ? null : Map<String, String>.from(headers),
            drmLicenseKey: licenseKey,
            drmLicenseUrl: licenseUrl,
            drmType: drmType,
            isDash: isDash,
            tvgId: tvgId,
            groupTitle: groupTitle,
          ));
        }

        // Reset so nothing leaks onto the next channel.
        resetPending();
      }
    }

    filteredChannels = List.from(channels);
    return channels;
  }

  // ------------------------------------------------------------
  // CLEARKEY PARSING
  // ------------------------------------------------------------

  // Accepts every key format seen in the playlists and returns
  // "kid:key,kid:key" in hex (or null if nothing usable):
  //   kid:key                                  (one pair)
  //   kid:key,kid:key                          (several pairs)
  //   {kid:key,kid:key}                        (braces, no quotes)
  //   {"kidHex":"keyHex", ...}                 (json map)
  //   {"keys":[{"kid":..,"k":..}]}             (JWK, base64 or base64url)
  // Placeholders such as null:null or 0000 give null.
  String? _parseLicenseKey(String value) {
    var v = value.trim();
    final pairs = <String>[];

    // {kid:key,kid:key} is not valid json: just drop the braces.
    if (v.startsWith('{') && !v.contains('"')) {
      v = v.substring(1, v.endsWith('}') ? v.length - 1 : v.length);
    }

    if (v.startsWith('{')) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          final keys = decoded['keys'];
          if (keys is List) {
            for (final k in keys) {
              if (k is Map && k['kid'] != null && k['k'] != null) {
                pairs.add('${_b64UrlToHex(k['kid'].toString())}:'
                    '${_b64UrlToHex(k['k'].toString())}');
              }
            }
          } else {
            decoded.forEach((kid, key) {
              final pair = '${kid.toString().trim()}:${key.toString().trim()}';
              if (_clearKeyPattern.hasMatch(pair)) pairs.add(pair);
            });
          }
        }
      } catch (_) {
        // malformed json -> keep whatever was read
      }
    } else {
      for (final p in v.split(',')) {
        final pair = p.trim();
        if (_clearKeyPattern.hasMatch(pair)) pairs.add(pair);
      }
    }

    return pairs.isEmpty ? null : pairs.join(',');
  }

  // base64 or base64url (padding optional) -> hex.
  String _b64UrlToHex(String s) {
    var t = s
        .trim()
        .replaceAll('-', '+')
        .replaceAll('_', '/')
        .replaceAll('=', '');
    t = t.padRight(t.length + (4 - t.length % 4) % 4, '=');
    return base64
        .decode(t)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ------------------------------------------------------------
  // EXTINF / HEADER PARSING
  // ------------------------------------------------------------

  // Parses a whole #EXTINF line:
  //   #EXTINF:-1 tvg-id="931" tvg-logo="https://..." group-title="Entertainment",Star Bharat HD
  // Attributes can be in any order and any of them can be missing.
  ({String name, String? logo, String? id, String? group}) _parseExtinf(
      String line) {
    final attrs = <String, String>{};
    for (final m in _attrPattern.allMatches(line)) {
      attrs[m.group(1)!.toLowerCase()] = m.group(2)!.trim();
    }

    // The name is everything after the first comma that follows the LAST
    // quote, so commas inside attribute values can't break it.
    final lastQuote = line.lastIndexOf('"');
    final commaIndex = line.indexOf(',', lastQuote == -1 ? 0 : lastQuote);
    var name = commaIndex == -1 ? '' : line.substring(commaIndex + 1).trim();
    if (name.isEmpty) name = attrs['tvg-name'] ?? 'Unnamed channel';

    String? clean(String? v) => (v == null || v.isEmpty) ? null : v;

    final logo = clean(attrs['tvg-logo']) ??
        clean(attrs['logo']) ??
        clean(attrs['tvg_logo']) ??
        clean(attrs['tvg-logo-small']);

    return (
    name: name,
    logo: (logo != null && isValidUrl(logo)) ? logo : null,
    id: clean(attrs['tvg-id']) ?? clean(attrs['tvg-chno']),
    group: clean(attrs['group-title']),
    );
  }

  // Parses "User-Agent=abc&Referer=https://x.com" into a header map.
  Map<String, String> _parseHeaderString(String raw) {
    final result = <String, String>{};
    for (final pair in raw.split('&')) {
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;

      final key = pair.substring(0, eq).trim();
      var value = pair.substring(eq + 1).trim();
      try {
        value = Uri.decodeComponent(value);
      } catch (_) {
        // keep the raw value if it isn't URL-encoded
      }
      if (key.isNotEmpty) result[key] = value;
    }
    return result;
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  String getDefaultLogoUrl() => 'assets/images/tv-icon.png';

  bool isValidUrl(String url) =>
      url.startsWith('https://') || url.startsWith('http://');

  // Search by name (as shown on screen and raw), tvg-id and group-title
  // (partial, case-insensitive).
  List<Channel> filterChannels(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filteredChannels = List.from(channels);
      return filteredChannels;
    }

    filteredChannels = channels.where((c) {
      return c.displayName.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          (c.tvgId?.toLowerCase().contains(q) ?? false) ||
          (c.groupTitle?.toLowerCase().contains(q) ?? false);
    }).toList();
    return filteredChannels;
  }
}