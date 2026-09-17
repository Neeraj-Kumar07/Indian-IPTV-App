import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
//added this 3rd import new in project
import 'package:flutter/services.dart' show rootBundle;


import '../model/channel.dart';
import '../model/stream_source.dart';

class ChannelsProvider with ChangeNotifier {
  static const streamsCatalogUrl =
      'https://raw.githubusercontent.com/kananinirav/Indian-IPTV-App/refs/heads/master/data/streams.csv';

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];

// this is old code  in comment
  /*Future<List<StreamSource>> fetchStreamSources() async {
    final response = await http.get(Uri.parse(streamsCatalogUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load stream sources');
    }

    final sources = <StreamSource>[];
    final lines = response.body.split('\n');

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
*/
  //  this is added new code for fetchStreamSources

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

  //here added code ends for fetchStreamSources

//this is the old code for fetchM3UFile
  /*

  Future<List<Channel>> fetchM3UFile(String sourceUrl) async {
    channels.clear();
    filteredChannels.clear();

    final response = await http.get(Uri.parse(sourceUrl));
    if (response.statusCode == 200) {
      String fileText = response.body;
      List<String> lines = fileText.split('\n');

      String? name;
      String logoUrl = getDefaultLogoUrl();
      String? streamUrl;

      for (String line in lines) {
        if (line.startsWith('#EXTINF:')) {
          name = extractChannelName(line);
          logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
        } else if (line.isNotEmpty && !line.startsWith('#')) {
          streamUrl = line.trim();
          if (name != null) {
            channels.add(Channel(
              name: name,
              logoUrl: logoUrl,
              streamUrl: streamUrl,
            ));
          }
          name = null;
          logoUrl = getDefaultLogoUrl();
          streamUrl = null;
        }
      }
      filteredChannels = List.from(channels);
      return channels;
    } else {
      throw Exception('Failed to load M3U file');
    }
  }

  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    List<String> parts = line.split(',');
    return parts.last.trim();
  }

  String? extractLogoUrl(String line) {
    List<String> parts = line.split('"');
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
*/
// this is the end of old code for fetchM3UFile

// this is the new code for fetchM3UFile
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
      fileText = response.body;
    }

    List<String> lines = fileText.split('\n');
    String? name;
    String logoUrl = getDefaultLogoUrl();
    String? streamUrl;

    for (String line in lines) {
      if (line.startsWith('#EXTINF:')) {
        name = extractChannelName(line);
        logoUrl = extractLogoUrl(line) ?? getDefaultLogoUrl();
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        streamUrl = line.trim();
        if (name != null) {
          channels.add(Channel(
            name: name,
            logoUrl: logoUrl,
            streamUrl: streamUrl,
          ));
        }
        name = null;
        logoUrl = getDefaultLogoUrl();
        streamUrl = null;
      }
    }

    filteredChannels = List.from(channels);
    return channels;
  }

  // helper methods must stay inside the class
  String getDefaultLogoUrl() {
    return 'assets/images/tv-icon.png';
  }

  String? extractChannelName(String line) {
    List<String> parts = line.split(',');
    return parts.last.trim();
  }

  String? extractLogoUrl(String line) {
    List<String> parts = line.split('"');
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
} // <-- make sure this closing brace is here

// this is the end  code  for fetchM3UFile new
