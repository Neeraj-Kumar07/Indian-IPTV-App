// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// //added this 3rd import new in project
// import 'package:flutter/services.dart' show rootBundle;
//
//
// import '../model/channel.dart';
// import '../model/stream_source.dart';
//
// class ChannelsProvider with ChangeNotifier {
//   static const streamsCatalogUrl =
//       'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';
//
//   List<Channel> channels = [];
//   List<Channel> filteredChannels = [];
//
// // this is old code  in comment
//   /*Future<List<StreamSource>> fetchStreamSources() async {
//     final response = await http.get(Uri.parse(streamsCatalogUrl));
//     if (response.statusCode != 200) {
//       throw Exception('Failed to load stream sources');
//     }
//
//     final sources = <StreamSource>[];
//     final lines = response.body.split('\n');
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
//       if (name.isNotEmpty && streamUrl.isNotEmpty) {
//         sources.add(StreamSource(name: name, streamUrl: streamUrl));
//       }
//     }
//
//     return sources;
//   }
// */
//   //  this is added new code for fetchStreamSources
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
//   //here added code ends for fetchStreamSources
//
// //this is the old code for fetchM3UFile
//   /*
//
//   Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
//     channels.clear();
//     filteredChannels.clear();
//
//     final response = await http.get(Uri.parse(sourceUrl));
//     if (response.statusCode == 200) {
//       String fileText = response.body;
//       List<String> lines = fileText.split('\n');
//
//       String? name;
//       String logoUrl = getDefaultLogoUrl();
//       String? streamUrl;
//
//       for (String line in lines) {
//         if (line.startsWith('#EXTINF:')) {
//           name = extractChannelName(line);
//           logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
//         } else if (line.isNotEmpty && !line.startsWith('#')) {
//           streamUrl = line.trim();
//           if (name != null) {
//             channels.add(Channel(
//               name: name,
//               logoUrl: logoUrl,
//               streamUrl: streamUrl,
//             ));
//           }
//           name = null;
//           logoUrl = getDefaultLogoUrl();
//           streamUrl = null;
//         }
//       }
//       filteredChannels = List.from(channels);
//       return channels;
//     } else {
//       throw Exception('Failed to load M3U file');
//     }
//   }
//
//   String getDefaultLogoUrl() {
//     return 'assets/images/tv-icon.png';
//   }
//
//   String? extractChannelName(String line) {
//     List<String> parts = line.split(',');
//     return parts.last.trim();
//   }
//
//   String? extractLogoUrl(String line) {
//     List<String> parts = line.split('"');
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
//             // channel.name.toLowerCase().contains(query.toLowerCase()))
//         .toList();
//     return filteredChannels;
//   }
// }
// */
// // this is the end of old code for fetchM3UFile
//
// // this is the new code for fetchM3UFile
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
//       fileText = response.body;
//     }
//
//     List<String> lines = fileText.split('\n');
//     String? name;
//     String logoUrl = getDefaultLogoUrl();
//     String? streamUrl;
//
//     for (String line in lines) {
//       if (line.startsWith('#EXTINF:')) {
//         name = extractChannelName(line);
//         logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
//       } else if (line.isNotEmpty && !line.startsWith('#')) {
//         streamUrl = line.trim();
//         if (name != null) {
//           channels.add(Channel(
//             name: name,
//             logoUrl: logoUrl,
//             streamUrl: streamUrl,
//           ));
//         }
//         name = null;
//         logoUrl = getDefaultLogoUrl();
//         streamUrl = null;
//       }
//     }
//
//     filteredChannels = List.from(channels);
//     return channels;
//   }
//
//   // helper methods must stay inside the class
//   String getDefaultLogoUrl() {
//     return 'assets/images/tv-icon.png';
//   }
//
//   String? extractChannelName(String line) {
//     List<String> parts = line.split(',');
//     return parts.last.trim();
//   }
//
//   String? extractLogoUrl(String line) {
//     List<String> parts = line.split('"');
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
// } // <-- make sure this closing brace is here
// ////////////////////////////////////////////////////////////////
// // this is the end  code  for fetchM3UFile new










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
    String? licenseKey;
    bool manifestIsDash = false;
    Map<String, String> headers = {};

    void resetPending() {
      name = null;
      logoUrl = getDefaultLogoUrl();
      licenseKey = null;
      manifestIsDash = false;
      headers = {};
    }

    for (final rawLine in lines) {
      final line = rawLine.trim(); // also removes '\r' from Windows files
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
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
          ));
        }

        // Reset so nothing leaks onto the next channel.
        resetPending();
      }
    }

    filteredChannels = List.from(channels);
    return channels;
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

  String? extractChannelName(String line) {
    final parts = line.split(',');
    return parts.last.trim();
  }

  String? extractLogoUrl(String line) {
    final parts = line.split('"');
    if (parts.length > 1 && isValidUrl(parts[1])) {
      return parts[1];
    } else if (parts.length > 5 && isValidUrl(parts[5])) {
      return parts[5];
    }
    return null;
  }

  bool isValidUrl(String url) {
    return url.startsWith('https') || url.startsWith('http');
  }

  List<Channel> filterChannels(String query) {
    filteredChannels = channels
        .where((channel) =>
        channel.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return filteredChannels;
  }
}
