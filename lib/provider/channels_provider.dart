//
// // ////////////////////////////////////////////////////////////////
// // // this is the end  code  for fetchM3UFile new
//
//
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:http/http.dart' as http;
//
// import '../model/channel.dart';
// import '../model/stream_source.dart';
//
// class ChannelsProvider with ChangeNotifier {
//   static const streamsCatalogUrl =
//       'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';
//
//   // A ClearKey license is "32 hex chars : 32 hex chars". Anything else
//   // (Widevine license URLs, JSON, etc.) is ignored so it can't crash the player.
//   static final RegExp _clearKeyPattern =
//   RegExp(r'^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$');
//
//   List<Channel> channels = [];
//   List<Channel> filteredChannels = [];
//
//   // ------------------------------------------------------------
//   // STREAM CATEGORIES (from the bundled data/streams.csv)
//   // ------------------------------------------------------------
//
//   Future<List<StreamSource>> fetchStreamSources() async {
//     final fileText = await rootBundle.loadString('data/streams.csv');
//     final sources = <StreamSource>[];
//     final lines = fileText.split('\n');
//
//     for (final line in lines) {
//       final trimmed = line.trim();
//       if (trimmed.isEmpty || trimmed.toLowerCase().startsWith('name,')) {
//         continue;
//       }
//
//       final commaIndex = trimmed.indexOf(',');
//       if (commaIndex == -1) continue;
//
//       final name = trimmed.substring(0, commaIndex).trim();
//       final streamUrl = trimmed.substring(commaIndex + 1).trim();
//
//       if (name.isNotEmpty && streamUrl.isNotEmpty) {
//         sources.add(StreamSource(name: name, streamUrl: streamUrl));
//       }
//     }
//
//     return sources;
//   }
//
//   // ------------------------------------------------------------
//   // M3U PARSER (with DRM + header support)
//   // ------------------------------------------------------------
//
//   Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
//     channels.clear();
//     filteredChannels.clear();
//
//     String fileText;
//
//     if (!sourceUrl.startsWith('http')) {
//       fileText = await rootBundle.loadString(sourceUrl);
//     } else {
//       final response = await http.get(Uri.parse(sourceUrl));
//       if (response.statusCode != 200) {
//         throw Exception('Failed to load M3U file');
//       }
//       fileText = utf8.decode(response.bodyBytes, allowMalformed: true);
//     }
//
//     final lines = fileText.split('\n');
//
//     // Values collected for the channel currently being parsed.
//     String? name;
//     String logoUrl = getDefaultLogoUrl();
//     String? licenseKey;
//     bool manifestIsDash = false;
//     Map<String, String> headers = {};
//
//     void resetPending() {
//       name = null;
//       logoUrl = getDefaultLogoUrl();
//       licenseKey = null;
//       manifestIsDash = false;
//       headers = {};
//     }
//
//     for (final rawLine in lines) {
//       final line = rawLine.trim(); // also removes '\r' from Windows files
//       if (line.isEmpty) continue;
//
//       if (line.startsWith('#EXTINF:')) {
//         name = extractChannelName(line);
//         logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
//       }
//       // ---- DRM: ClearKey ----
//       else if (line.startsWith('#KODIPROP:inputstream.adaptive.license_key=')) {
//         final value = line.substring(line.indexOf('=') + 1).trim();
//         if (_clearKeyPattern.hasMatch(value)) {
//           licenseKey = value;
//         }
//       }
//       // ---- Manifest type hint ----
//       else if (line.startsWith('#KODIPROP:inputstream.adaptive.manifest_type=')) {
//         final value = line.substring(line.indexOf('=') + 1).trim().toLowerCase();
//         manifestIsDash = value == 'mpd' || value == 'dash';
//       }
//       // ---- Headers: Kodi style "User-Agent=x&Referer=y" ----
//       else if (line.startsWith('#KODIPROP:inputstream.adaptive.stream_headers=') ||
//           line.startsWith('#KODIPROP:inputstream.adaptive.manifest_headers=')) {
//         headers.addAll(_parseHeaderString(line.substring(line.indexOf('=') + 1)));
//       }
//       // ---- Headers: VLC style ----
//       else if (line.startsWith('#EXTVLCOPT:http-user-agent=')) {
//         headers['User-Agent'] = line.substring(line.indexOf('=') + 1).trim();
//       } else if (line.startsWith('#EXTVLCOPT:http-referrer=') ||
//           line.startsWith('#EXTVLCOPT:http-referer=')) {
//         headers['Referer'] = line.substring(line.indexOf('=') + 1).trim();
//       } else if (line.startsWith('#EXTVLCOPT:http-origin=')) {
//         headers['Origin'] = line.substring(line.indexOf('=') + 1).trim();
//       }
//       // ---- Headers: JSON style  #EXTHTTP:{"cookie":"..."} ----
//       else if (line.startsWith('#EXTHTTP:')) {
//         try {
//           final decoded = jsonDecode(line.substring('#EXTHTTP:'.length));
//           if (decoded is Map) {
//             decoded.forEach((k, v) => headers[k.toString()] = v.toString());
//           }
//         } catch (_) {
//           // ignore malformed JSON
//         }
//       }
//       // ---- Any other comment / tag line ----
//       else if (line.startsWith('#')) {
//         continue;
//       }
//       // ---- Stream URL line: build the channel ----
//       else {
//         var streamUrl = line;
//
//         // Some playlists append headers to the URL: url|User-Agent=x&Referer=y
//         final pipeIndex = streamUrl.indexOf('|');
//         if (pipeIndex != -1) {
//           headers.addAll(_parseHeaderString(streamUrl.substring(pipeIndex + 1)));
//           streamUrl = streamUrl.substring(0, pipeIndex).trim();
//         }
//
//         if (name != null && streamUrl.isNotEmpty) {
//           final lowerUrl = streamUrl.toLowerCase();
//           final isDash = manifestIsDash ||
//               lowerUrl.contains('.mpd') ||
//               lowerUrl.contains('manifest_type=mpd');
//
//           channels.add(Channel(
//             name: name!,
//             logoUrl: logoUrl,
//             streamUrl: streamUrl,
//             httpHeaders: headers.isEmpty ? null : Map<String, String>.from(headers),
//             drmLicenseKey: licenseKey,
//             isDash: isDash,
//           ));
//         }
//
//         // Reset so nothing leaks onto the next channel.
//         resetPending();
//       }
//     }
//
//     filteredChannels = List.from(channels);
//     return channels;
//   }
//
//   // Parses "User-Agent=abc&Referer=https://x.com" into a header map.
//   Map<String, String> _parseHeaderString(String raw) {
//     final result = <String, String>{};
//     for (final pair in raw.split('&')) {
//       final eq = pair.indexOf('=');
//       if (eq <= 0) continue;
//
//       final key = pair.substring(0, eq).trim();
//       var value = pair.substring(eq + 1).trim();
//       try {
//         value = Uri.decodeComponent(value);
//       } catch (_) {
//         // keep the raw value if it isn't URL-encoded
//       }
//       if (key.isNotEmpty) result[key] = value;
//     }
//     return result;
//   }
//
//   // ------------------------------------------------------------
//   // HELPERS
//   // ------------------------------------------------------------
//
//   String getDefaultLogoUrl() {
//     return 'assets/images/tv-icon.png';
//   }
//
//   String? extractChannelName(String line) {
//     final parts = line.split(',');
//     return parts.last.trim();
//   }
//
//   String? extractLogoUrl(String line) {
//     final parts = line.split('"');
//     if (parts.length > 1 && isValidUrl(parts[1])) {
//       return parts[1];
//     } else if (parts.length > 5 && isValidUrl(parts[5])) {
//       return parts[5];
//     }
//     return null;
//   }
//
//   bool isValidUrl(String url) {
//     return url.startsWith('https') || url.startsWith('http');
//   }
//
//   List<Channel> filterChannels(String query) {
//     filteredChannels = channels
//         .where((channel) =>
//         channel.name.toLowerCase().contains(query.toLowerCase()))
//         .toList();
//     return filteredChannels;
//   }
// }


///////////////////////////////////////////////////////////////


import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../model/channel.dart';
import '../model/stream_source.dart';

class ChannelsProvider with ChangeNotifier {
  static const streamsCatalogUrl =
      'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';

  // A ClearKey license is "32 hex chars : 32 hex chars". Anything else
  // (Widevine license URLs, JSON, etc.) is ignored so it can't crash the player.
  static final RegExp _clearKeyPattern =
  RegExp(r'^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$');

  // Matches key="value" pairs inside an #EXTINF line, in any order.
  static final RegExp _attrPattern = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];

  // ------------------------------------------------------------
  // STREAM CATEGORIES (from the bundled data/streams.csv)
  // ------------------------------------------------------------

  Future<List<StreamSource>> fetchStreamSources() async {
    final fileText = await rootBundle.loadString('data/streams.csv');
    final sources = <StreamSource>[];
    final lines = fileText.split('\n');

    for (final line in lines) {
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

    String fileText;

    if (!sourceUrl.startsWith('http')) {
      fileText = await rootBundle.loadString(sourceUrl);
    } else {
      final response = await http.get(Uri.parse(sourceUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load M3U file');
      }
      fileText = utf8.decode(response.bodyBytes, allowMalformed: true);
    }

    final lines = fileText.split('\n');

    // Values collected for the channel currently being parsed.
    String? name;
    String logoUrl = getDefaultLogoUrl();
    String? tvgId;
    String? groupTitle;
    String? licenseKey;
    bool manifestIsDash = false;
    Map<String, String> headers = {};

    void resetPending() {
      name = null;
      logoUrl = getDefaultLogoUrl();
      tvgId = null;
      groupTitle = null;
      licenseKey = null;
      manifestIsDash = false;
      headers = {};
    }

    for (final rawLine in lines) {
      final line = rawLine.trim(); // also removes '\r' from Windows files
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final info = _parseExtinf(line);
        name = info.name;
        logoUrl = info.logo ?? getDefaultLogoUrl();
        tvgId = info.id;
        groupTitle = info.group;
      }
      // ---- DRM: ClearKey ----
      else if (line.startsWith('#KODIPROP:inputstream.adaptive.license_key=')) {
        final value = line.substring(line.indexOf('=') + 1).trim();
        if (_clearKeyPattern.hasMatch(value)) {
          licenseKey = value;
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
        headers.addAll(_parseHeaderString(line.substring(line.indexOf('=') + 1)));
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
            decoded.forEach((k, v) => headers[k.toString()] = v.toString());
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
          headers.addAll(_parseHeaderString(streamUrl.substring(pipeIndex + 1)));
          streamUrl = streamUrl.substring(0, pipeIndex).trim();
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
            httpHeaders: headers.isEmpty ? null : Map<String, String>.from(headers),
            drmLicenseKey: licenseKey,
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

    final logo = clean(attrs['tvg-logo']);

    return (
    name: name,
    logo: (logo != null && isValidUrl(logo)) ? logo : null,
    // tvg-id first; tvg-chno is used when a playlist only has channel numbers.
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

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  bool isValidUrl(String url) {
    return url.startsWith('https') || url.startsWith('http');
  }

  // Search by name, tvg-id and group-title (partial, case-insensitive).
  List<Channel> filterChannels(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filteredChannels = List.from(channels);
      return filteredChannels;
    }

    filteredChannels = channels.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.tvgId?.toLowerCase().contains(q) ?? false) ||
          (c.groupTitle?.toLowerCase().contains(q) ?? false);
    }).toList();
    return filteredChannels;
  }
}
