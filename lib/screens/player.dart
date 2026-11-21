//
//
// /////////////////////////////////////////////////////
//
// // lib/screens/player.dart
// //
// // Based on your current version. Changes:
// //  * ClearKey license URL support: the key set is fetched when the channel
// //    opens, converted to ClearKey JSON and given to ExoPlayer.
// //  * Several keys ("kid:key,kid:key") work for direct keys too.
// //  * Widevine is detected with contains('widevine') (Kodi writes
// //    "com.widevine.alpha").
// //  * The reason for a failure is shown in small print under the message.
// //
// // Needs the `http` package (already used by channels_provider.dart).
//
// import 'dart:async';
// import 'dart:convert';
//
// import 'package:better_player_plus/better_player_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:wakelock_plus/wakelock_plus.dart';
//
// import '../model/channel.dart';
//
// class Player extends StatefulWidget {
//   final Channel channel;
//
//   const Player({super.key, required this.channel});
//
//   @override
//   State<Player> createState() => _PlayerState();
// }
//
// class _PlayerState extends State<Player> {
//   // Created in _init(), because a license URL has to be fetched first.
//   BetterPlayerController? _controller;
//
//   bool _isLoading = true;
//   bool _isBuffering = false;
//   bool _channelNotFound = false;
//   bool _showOverlay = true;
//
//   String? _errorText;
//
//   Timer? _overlayTimer;
//
//   static final RegExp _hex32 = RegExp(r'^[0-9a-fA-F]{32}$');
//   static final RegExp _pairPattern =
//   RegExp(r'^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$');
//
//   // ------------------------------------------------------------
//   // Format helpers
//   // ------------------------------------------------------------
//
//   // BetterPlayerVideoFormat _formatFor(String url) {
//   //   final value = url.toLowerCase();
//   //
//   //   if (widget.channel.isDash || value.contains('.mpd')) {
//   //     return BetterPlayerVideoFormat.dash;
//   //   }
//   //   if (value.contains('.m3u8')) {
//   //     return BetterPlayerVideoFormat.hls;
//   //   }
//   //   return BetterPlayerVideoFormat.other;
//   // }
//
//   BetterPlayerVideoFormat _formatFor(String url) {
//     final value = url.toLowerCase();
//
//     if (value.contains('.mpd')) return BetterPlayerVideoFormat.dash;
//     if (value.contains('.m3u8')) return BetterPlayerVideoFormat.hls;
//
//     // No extension in the URL: fall back to the playlist's hint.
//     if (widget.channel.isDash) return BetterPlayerVideoFormat.dash;
//     return BetterPlayerVideoFormat.other;
//   }
//
//   // When the URL has no .mpd / .m3u8 (a worker or redirect URL, for example)
//   // look at the first bytes of the answer instead of guessing.
//   Future<BetterPlayerVideoFormat> _resolveFormat(String url) async {
//     final known = _formatFor(url);
//     if (known != BetterPlayerVideoFormat.other) return known;
//
//     final client = http.Client();
//     try {
//       final request = http.Request('GET', Uri.parse(url));
//       request.headers.addAll(widget.channel.httpHeaders ?? const {});
//
//       final response =
//       await client.send(request).timeout(const Duration(seconds: 8));
//
//       final type = (response.headers['content-type'] ?? '').toLowerCase();
//       if (type.contains('dash+xml')) return BetterPlayerVideoFormat.dash;
//       if (type.contains('mpegurl')) return BetterPlayerVideoFormat.hls;
//
//       // Only the first chunk is read, so a live stream is never downloaded.
//       final chunk =
//       await response.stream.first.timeout(const Duration(seconds: 8));
//       final head = utf8
//           .decode(chunk.take(2000).toList(), allowMalformed: true)
//           .toLowerCase();
//
//       if (head.contains('<mpd')) return BetterPlayerVideoFormat.dash;
//       if (head.contains('#extm3u')) return BetterPlayerVideoFormat.hls;
//     } catch (_) {
//       // fall through: keep "other"
//     } finally {
//       client.close();
//     }
//     return BetterPlayerVideoFormat.other;
//   }
//
//   // ------------------------------------------------------------
//   // ClearKey helpers
//   // ------------------------------------------------------------
//
//   // Hex string -> bytes -> base64url without '=' padding.
//   String _hexToB64Url(String hex) {
//     final bytes = <int>[];
//     for (var i = 0; i + 1 < hex.length; i += 2) {
//       bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
//     }
//     return base64Url.encode(bytes).replaceAll('=', '');
//   }
//
//   // "kid:key" or "kid:key,kid:key" (hex) -> ClearKey JSON. Null if no pair.
//   String? _clearKeyJson(String? licenseKey) {
//     if (licenseKey == null) return null;
//
//     final keys = <Map<String, String>>[];
//     for (final part in licenseKey.split(',')) {
//       final pair = part.trim();
//       if (!_pairPattern.hasMatch(pair)) continue;
//
//       final pieces = pair.split(':');
//       keys.add({
//         'kty': 'oct',
//         'k': _hexToB64Url(pieces[1]),
//         'kid': _hexToB64Url(pieces[0]),
//       });
//     }
//     if (keys.isEmpty) return null;
//
//     return jsonEncode({'keys': keys, 'type': 'temporary'});
//   }
//
//   // hex or base64/base64url -> base64url without padding.
//   String _toB64Url(String v) {
//     final t = v.trim();
//     if (_hex32.hasMatch(t)) return _hexToB64Url(t);
//     return t.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
//   }
//
//   // Turns a license server answer into ClearKey JSON. Accepts:
//   //   {"keys":[{"kty":"oct","k":"..","kid":".."}]}  (base64, base64url or hex)
//   //   {"kidHex":"keyHex", ...}
//   //   kid:key  or  kid:key,kid:key  (also inside braces, without quotes)
//   // Returns null for anything else.
//   String? _clearKeyJsonFromResponse(String body) {
//     var text = body.trim();
//     if (text.isEmpty) return null;
//
//     if (text.startsWith('{') && !text.contains('"')) {
//       text = text.substring(
//           1, text.endsWith('}') ? text.length - 1 : text.length);
//     }
//
//     if (text.startsWith('{')) {
//       try {
//         final decoded = jsonDecode(text);
//         if (decoded is! Map) return null;
//
//         final out = <Map<String, String>>[];
//         final keys = decoded['keys'];
//
//         if (keys is List) {
//           for (final entry in keys) {
//             if (entry is! Map || entry['kid'] == null || entry['k'] == null) {
//               continue;
//             }
//             out.add({
//               'kty': 'oct',
//               'k': _toB64Url(entry['k'].toString()),
//               'kid': _toB64Url(entry['kid'].toString()),
//             });
//           }
//         } else {
//           decoded.forEach((kid, key) {
//             final id = kid.toString().trim();
//             final k = key.toString().trim();
//             if (_hex32.hasMatch(id) && _hex32.hasMatch(k)) {
//               out.add({
//                 'kty': 'oct',
//                 'k': _hexToB64Url(k),
//                 'kid': _hexToB64Url(id),
//               });
//             }
//           });
//         }
//
//         if (out.isEmpty) return null;
//         return jsonEncode({'keys': out, 'type': 'temporary'});
//       } catch (_) {
//         return null;
//       }
//     }
//
//     return _clearKeyJson(text);
//   }
//
//   // Asks the ClearKey license URL for the keys (plain GET with the
//   // channel's own headers). Null on any failure; _errorText says why.
//   Future<String?> _fetchClearKeyJson(String licenseUrl) async {
//     try {
//       final response = await http
//           .get(Uri.parse(licenseUrl), headers: widget.channel.httpHeaders)
//           .timeout(const Duration(seconds: 10));
//
//       if (response.statusCode != 200) {
//         _errorText = 'License server answered HTTP ${response.statusCode}';
//         return null;
//       }
//
//       final json = _clearKeyJsonFromResponse(
//         utf8.decode(response.bodyBytes, allowMalformed: true),
//       );
//       if (json == null) {
//         _errorText = 'License response was not a ClearKey key set';
//       }
//       return json;
//     } catch (e) {
//       _errorText = 'Could not get the license: $e';
//       return null;
//     }
//   }
//
//   // ------------------------------------------------------------
//   // Start-up
//   // ------------------------------------------------------------
//
//   @override
//   void initState() {
//     super.initState();
//
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//     WakelockPlus.enable();
//
//     _init();
//     _showOverlayTemporarily();
//   }
//
//   Future<void> _init() async {
//     final channel = widget.channel;
//     final url = channel.streamUrl;
//     final type = channel.drmType?.toLowerCase() ?? '';
//     final licenseUrl = channel.drmLicenseUrl;
//
//     BetterPlayerDrmConfiguration? drm;
//
//     // 1) Direct hex key(s) in the playlist (existing behaviour).
//     var clearKey = _clearKeyJson(channel.drmLicenseKey);
//
//     // 2) ClearKey license URL: fetch the keys now.
//     if (clearKey == null &&
//         licenseUrl != null &&
//         licenseUrl.isNotEmpty &&
//         (type.isEmpty || type.contains('clearkey'))) {
//       clearKey = await _fetchClearKeyJson(licenseUrl);
//       if (!mounted) return;
//
//       if (clearKey == null) {
//         setState(() {
//           _isLoading = false;
//           _channelNotFound = true;
//         });
//         return;
//       }
//     }
//
//     if (clearKey != null) {
//       drm = BetterPlayerDrmConfiguration(
//         drmType: BetterPlayerDrmType.clearKey,
//         clearKey: clearKey,
//       );
//     } else if (type.contains('widevine')) {
//       // Widevine license server. The server must authorize the request.
//       if (licenseUrl != null && licenseUrl.isNotEmpty) {
//         drm = BetterPlayerDrmConfiguration(
//           drmType: BetterPlayerDrmType.widevine,
//           licenseUrl: licenseUrl,
//           headers: channel.httpHeaders,
//         );
//       } else {
//         debugPrint('Widevine channel has no license URL.');
//       }
//     }
//
//     final format = await _resolveFormat(url);
//     if (!mounted) return;
//
//     final dataSource = BetterPlayerDataSource(
//       BetterPlayerDataSourceType.network,
//       url,
//       headers: channel.httpHeaders,
//       videoFormat: format,
//       liveStream: true,
//       drmConfiguration: drm,
//     );
//
//     final controller = BetterPlayerController(
//       const BetterPlayerConfiguration(
//         autoPlay: true,
//         fit: BoxFit.fill,
//         aspectRatio: 16 / 9,
//         controlsConfiguration: BetterPlayerControlsConfiguration(
//           showControls: false,
//         ),
//       ),
//       betterPlayerDataSource: dataSource,
//     );
//
//     controller.addEventsListener((event) {
//       if (!mounted) return;
//
//       switch (event.betterPlayerEventType) {
//         case BetterPlayerEventType.initialized:
//           setState(() {
//             _isLoading = false;
//             _channelNotFound = false;
//           });
//           break;
//
//         case BetterPlayerEventType.bufferingStart:
//           setState(() => _isBuffering = true);
//           break;
//
//         case BetterPlayerEventType.bufferingEnd:
//           setState(() => _isBuffering = false);
//           break;
//
//         case BetterPlayerEventType.exception:
//           debugPrint('Player error for $url: ${event.parameters}');
//
//           setState(() {
//             _isLoading = false;
//             _isBuffering = false;
//             _channelNotFound = true;
//             _errorText = event.parameters?.toString();
//           });
//           break;
//
//         default:
//           break;
//       }
//     });
//
//     setState(() => _controller = controller);
//   }
//
//   // ------------------------------------------------------------
//   // Overlay / lifecycle
//   // ------------------------------------------------------------
//
//   void _showOverlayTemporarily() {
//     _overlayTimer?.cancel();
//
//     if (!_showOverlay && mounted) {
//       setState(() => _showOverlay = true);
//     }
//
//     _overlayTimer = Timer(
//       const Duration(seconds: 4),
//           () {
//         if (mounted) {
//           setState(() => _showOverlay = false);
//         }
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _overlayTimer?.cancel();
//     _controller?.dispose(forceDispose: true);
//     WakelockPlus.disable();
//
//     SystemChrome.setEnabledSystemUIMode(
//       SystemUiMode.manual,
//       overlays: SystemUiOverlay.values,
//     );
//
//     super.dispose();
//   }
//
//   Widget _buildVideo() {
//     final controller = _controller;
//     if (controller == null) return const SizedBox.shrink();
//
//     return SizedBox.expand(
//       child: BetterPlayer(controller: controller),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Focus(
//         autofocus: true,
//         onKeyEvent: (node, event) {
//           if (event is KeyDownEvent) {
//             _showOverlayTemporarily();
//           }
//           return KeyEventResult.ignored;
//         },
//         child: GestureDetector(
//           behavior: HitTestBehavior.opaque,
//           onTap: _showOverlayTemporarily,
//           child: Stack(
//             fit: StackFit.expand,
//             children: [
//               if (!_channelNotFound) _buildVideo(),
//
//               if (_channelNotFound)
//                 Center(
//                   child: Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 24),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Text(
//                           'Channel not available now',
//                           style: TextStyle(
//                             fontSize: 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                         if (_errorText != null) ...[
//                           const SizedBox(height: 12),
//                           Text(
//                             _errorText!,
//                             maxLines: 6,
//                             overflow: TextOverflow.ellipsis,
//                             textAlign: TextAlign.center,
//                             style: const TextStyle(
//                               fontSize: 12,
//                               color: Colors.white54,
//                             ),
//                           ),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ),
//
//               if (!_channelNotFound && (_isLoading || _isBuffering))
//                 const Center(
//                   child: CircularProgressIndicator(),
//                 ),
//
//               AnimatedOpacity(
//                 opacity: _showOverlay ? 1 : 0,
//                 duration: const Duration(milliseconds: 250),
//                 child: IgnorePointer(
//                   ignoring: !_showOverlay,
//                   child: Align(
//                     alignment: Alignment.topCenter,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 8,
//                       ),
//                       decoration: const BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                           colors: [
//                             Colors.black87,
//                             Colors.transparent,
//                           ],
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           IconButton(
//                             icon: const Icon(
//                               Icons.arrow_back,
//                               color: Colors.white,
//                             ),
//                             onPressed: () {
//                               Navigator.of(context).pop();
//                             },
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               widget.channel.name,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 20,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }



//////////////////////////////

/////////////////////////////////////////////////////

// lib/screens/player.dart
//
// Based on your current version. Changes:
//  * ClearKey license URL support: the key set is fetched when the channel
//    opens, converted to ClearKey JSON and given to ExoPlayer.
//  * Several keys ("kid:key,kid:key") work for direct keys too.
//  * Widevine is detected with contains('widevine') (Kodi writes
//    "com.widevine.alpha").
//  * The reason for a failure is shown in small print under the message.
//
// ===================== SEEK BAR CHANGES (NEW) =====================
// Everything marked "CHANGE [n]" below is new. Nothing else was touched.
//
//  CHANGE [1] State variables (_isSeekable, _dragging, _position, _duration)
//  CHANGE [2] Helper methods (_syncTiming, _seekTo, _seekBy,
//             _togglePlayPause, _fmt, _buildSeekBar)
//  CHANGE [3] Event listener: calls _syncTiming() on `initialized` and
//             on the new `progress` case
//  CHANGE [4] Remote / keyboard seeking in build() -> Focus.onKeyEvent
//             (Left/Right = -/+10s, OK/Enter/Play-Pause = pause/play)
//  CHANGE [5] Seek bar widget added at the bottom of the Stack in build()
//  (v2) FIX A: movie detection needs a duration of 10+ minutes, so live
//       streams with a short sliding window no longer get a bar.
//  (v2) FIX B: bar is positioned with Positioned at the bottom of the video.
//
// How it works: live streams report no usable duration, so _isSeekable
// stays false and live channels behave exactly as before. Movies report a
// real duration, so the seek bar and remote seeking turn on automatically.
// ==================================================================
//
// Needs the `http` package (already used by channels_provider.dart).

import 'dart:async';
import 'dart:convert';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/channel.dart';

class Player extends StatefulWidget {
  final Channel channel;

  const Player({super.key, required this.channel});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  // Created in _init(), because a license URL has to be fetched first.
  BetterPlayerController? _controller;

  bool _isLoading = true;
  bool _isBuffering = false;
  bool _channelNotFound = false;
  bool _showOverlay = true;

  String? _errorText;

  // ---------------------------------------------------------------
  // CHANGE [1]: NEW state variables for the seek bar.
  //   _isSeekable : true only when the stream has a real duration (movie).
  //                 Stays false for live TV, so nothing changes there.
  //   _dragging   : true while the user drags the slider handle.
  //   _position   : current playhead position.
  //   _duration   : total length of the movie.
  // ---------------------------------------------------------------
  bool _isSeekable = false;
  bool _dragging = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Timer? _overlayTimer;

  static final RegExp _hex32 = RegExp(r'^[0-9a-fA-F]{32}$');
  static final RegExp _pairPattern =
  RegExp(r'^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$');

  // ------------------------------------------------------------
  // Format helpers
  // ------------------------------------------------------------

  // BetterPlayerVideoFormat _formatFor(String url) {
  //   final value = url.toLowerCase();
  //
  //   if (widget.channel.isDash || value.contains('.mpd')) {
  //     return BetterPlayerVideoFormat.dash;
  //   }
  //   if (value.contains('.m3u8')) {
  //     return BetterPlayerVideoFormat.hls;
  //   }
  //   return BetterPlayerVideoFormat.other;
  // }

  BetterPlayerVideoFormat _formatFor(String url) {
    final value = url.toLowerCase();

    if (value.contains('.mpd')) return BetterPlayerVideoFormat.dash;
    if (value.contains('.m3u8')) return BetterPlayerVideoFormat.hls;

    // No extension in the URL: fall back to the playlist's hint.
    if (widget.channel.isDash) return BetterPlayerVideoFormat.dash;
    return BetterPlayerVideoFormat.other;
  }

  // When the URL has no .mpd / .m3u8 (a worker or redirect URL, for example)
  // look at the first bytes of the answer instead of guessing.
  Future<BetterPlayerVideoFormat> _resolveFormat(String url) async {
    final known = _formatFor(url);
    if (known != BetterPlayerVideoFormat.other) return known;

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(widget.channel.httpHeaders ?? const {});

      final response =
      await client.send(request).timeout(const Duration(seconds: 8));

      final type = (response.headers['content-type'] ?? '').toLowerCase();
      if (type.contains('dash+xml')) return BetterPlayerVideoFormat.dash;
      if (type.contains('mpegurl')) return BetterPlayerVideoFormat.hls;

      // Only the first chunk is read, so a live stream is never downloaded.
      final chunk =
      await response.stream.first.timeout(const Duration(seconds: 8));
      final head = utf8
          .decode(chunk.take(2000).toList(), allowMalformed: true)
          .toLowerCase();

      if (head.contains('<mpd')) return BetterPlayerVideoFormat.dash;
      if (head.contains('#extm3u')) return BetterPlayerVideoFormat.hls;
    } catch (_) {
      // fall through: keep "other"
    } finally {
      client.close();
    }
    return BetterPlayerVideoFormat.other;
  }

  // ------------------------------------------------------------
  // ClearKey helpers
  // ------------------------------------------------------------

  // Hex string -> bytes -> base64url without '=' padding.
  String _hexToB64Url(String hex) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // "kid:key" or "kid:key,kid:key" (hex) -> ClearKey JSON. Null if no pair.
  String? _clearKeyJson(String? licenseKey) {
    if (licenseKey == null) return null;

    final keys = <Map<String, String>>[];
    for (final part in licenseKey.split(',')) {
      final pair = part.trim();
      if (!_pairPattern.hasMatch(pair)) continue;

      final pieces = pair.split(':');
      keys.add({
        'kty': 'oct',
        'k': _hexToB64Url(pieces[1]),
        'kid': _hexToB64Url(pieces[0]),
      });
    }
    if (keys.isEmpty) return null;

    return jsonEncode({'keys': keys, 'type': 'temporary'});
  }

  // hex or base64/base64url -> base64url without padding.
  String _toB64Url(String v) {
    final t = v.trim();
    if (_hex32.hasMatch(t)) return _hexToB64Url(t);
    return t.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }

  // Turns a license server answer into ClearKey JSON. Accepts:
  //   {"keys":[{"kty":"oct","k":"..","kid":".."}]}  (base64, base64url or hex)
  //   {"kidHex":"keyHex", ...}
  //   kid:key  or  kid:key,kid:key  (also inside braces, without quotes)
  // Returns null for anything else.
  String? _clearKeyJsonFromResponse(String body) {
    var text = body.trim();
    if (text.isEmpty) return null;

    if (text.startsWith('{') && !text.contains('"')) {
      text = text.substring(
          1, text.endsWith('}') ? text.length - 1 : text.length);
    }

    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is! Map) return null;

        final out = <Map<String, String>>[];
        final keys = decoded['keys'];

        if (keys is List) {
          for (final entry in keys) {
            if (entry is! Map || entry['kid'] == null || entry['k'] == null) {
              continue;
            }
            out.add({
              'kty': 'oct',
              'k': _toB64Url(entry['k'].toString()),
              'kid': _toB64Url(entry['kid'].toString()),
            });
          }
        } else {
          decoded.forEach((kid, key) {
            final id = kid.toString().trim();
            final k = key.toString().trim();
            if (_hex32.hasMatch(id) && _hex32.hasMatch(k)) {
              out.add({
                'kty': 'oct',
                'k': _hexToB64Url(k),
                'kid': _hexToB64Url(id),
              });
            }
          });
        }

        if (out.isEmpty) return null;
        return jsonEncode({'keys': out, 'type': 'temporary'});
      } catch (_) {
        return null;
      }
    }

    return _clearKeyJson(text);
  }

  // Asks the ClearKey license URL for the keys (plain GET with the
  // channel's own headers). Null on any failure; _errorText says why.
  Future<String?> _fetchClearKeyJson(String licenseUrl) async {
    try {
      final response = await http
          .get(Uri.parse(licenseUrl), headers: widget.channel.httpHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _errorText = 'License server answered HTTP ${response.statusCode}';
        return null;
      }

      final json = _clearKeyJsonFromResponse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (json == null) {
        _errorText = 'License response was not a ClearKey key set';
      }
      return json;
    } catch (e) {
      _errorText = 'Could not get the license: $e';
      return null;
    }
  }

  // ------------------------------------------------------------
  // Start-up
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    _init();
    _showOverlayTemporarily();
  }

  Future<void> _init() async {
    final channel = widget.channel;
    final url = channel.streamUrl;
    final type = channel.drmType?.toLowerCase() ?? '';
    final licenseUrl = channel.drmLicenseUrl;

    BetterPlayerDrmConfiguration? drm;

    // 1) Direct hex key(s) in the playlist (existing behaviour).
    var clearKey = _clearKeyJson(channel.drmLicenseKey);

    // 2) ClearKey license URL: fetch the keys now.
    if (clearKey == null &&
        licenseUrl != null &&
        licenseUrl.isNotEmpty &&
        (type.isEmpty || type.contains('clearkey'))) {
      clearKey = await _fetchClearKeyJson(licenseUrl);
      if (!mounted) return;

      if (clearKey == null) {
        setState(() {
          _isLoading = false;
          _channelNotFound = true;
        });
        return;
      }
    }

    if (clearKey != null) {
      drm = BetterPlayerDrmConfiguration(
        drmType: BetterPlayerDrmType.clearKey,
        clearKey: clearKey,
      );
    } else if (type.contains('widevine')) {
      // Widevine license server. The server must authorize the request.
      if (licenseUrl != null && licenseUrl.isNotEmpty) {
        drm = BetterPlayerDrmConfiguration(
          drmType: BetterPlayerDrmType.widevine,
          licenseUrl: licenseUrl,
          headers: channel.httpHeaders,
        );
      } else {
        debugPrint('Widevine channel has no license URL.');
      }
    }

    final format = await _resolveFormat(url);
    if (!mounted) return;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      headers: channel.httpHeaders,
      videoFormat: format,
      liveStream: true,
      drmConfiguration: drm,
    );

    final controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.fill,
        aspectRatio: 16 / 9,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    controller.addEventsListener((event) {
      if (!mounted) return;

      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
          setState(() {
            _isLoading = false;
            _channelNotFound = false;
          });
          // CHANGE [3a]: NEW line. Check right after start-up whether this
          // stream has a real duration (movie) or not (live TV).
          _syncTiming();
          break;

      // CHANGE [3b]: NEW case. The player sends `progress` events while
      // playing; we use them to keep the playhead position up to date
      // (and to catch a duration that arrives a little late).
        case BetterPlayerEventType.progress:
          _syncTiming();
          break;

        case BetterPlayerEventType.bufferingStart:
          setState(() => _isBuffering = true);
          break;

        case BetterPlayerEventType.bufferingEnd:
          setState(() => _isBuffering = false);
          break;

        case BetterPlayerEventType.exception:
          debugPrint('Player error for $url: ${event.parameters}');

          setState(() {
            _isLoading = false;
            _isBuffering = false;
            _channelNotFound = true;
            _errorText = event.parameters?.toString();
          });
          break;

        default:
          break;
      }
    });

    setState(() => _controller = controller);
  }

  // ------------------------------------------------------------
  // CHANGE [2]: NEW seek bar helpers (movies only)
  // ------------------------------------------------------------

  // FIX A (2nd version): a live HLS stream reports a short sliding window
  // (for example 58 seconds) as its "duration", which wrongly turned the
  // seek bar on for live channels. A stream now counts as a movie only if
  // its duration is at least this long. Raise it if a live channel still
  // shows a bar, lower it if a very short video should have one.
  static const Duration _minMovieLength = Duration(minutes: 10);

  // Reads duration/position from the player and decides if this is a movie.
  // Live streams return early here (no seek bar, no rebuilds).
  void _syncTiming() {
    final value = _controller?.videoPlayerController?.value;
    if (value == null) return;

    // Read through `dynamic` so this compiles cleanly whether the package
    // declares duration as nullable or not (removes the
    // "operand can't be null" warning).
    final dynamic raw = value.duration;
    final Duration d = raw is Duration ? raw : Duration.zero;

    final valid = d >= _minMovieLength && d < const Duration(hours: 24);

    // Live stream: nothing to show, nothing to rebuild.
    if (!valid && !_isSeekable) return;

    setState(() {
      _isSeekable = valid;
      if (valid) {
        _duration = d;
        if (!_dragging) _position = value.position;
      }
    });
  }

  // Jumps the video to [target] (kept inside 0..duration).
  void _seekTo(Duration target) {
    var t = target;
    if (t < Duration.zero) t = Duration.zero;
    if (t > _duration) t = _duration;
    _controller?.seekTo(t);
    setState(() => _position = t);
  }

  // Moves forward/backward by [delta] (used by the remote's Left/Right).
  void _seekBy(Duration delta) => _seekTo(_position + delta);

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.isPlaying() ?? false) {
      c.pause();
    } else {
      c.play();
    }
  }

  // 3725 seconds -> "1:02:05", 125 seconds -> "02:05".
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // The bar itself: current time | slider | total time.
  Widget _buildSeekBar() {
    final maxMs = _duration.inMilliseconds.toDouble();
    final valueMs =
    _position.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Text(_fmt(_position),
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          Expanded(
            // ExcludeFocus: the TV remote's left/right keys are handled by
            // the screen itself (see onKeyEvent in build()), not the slider.
            child: ExcludeFocus(
              child: Slider(
                value: valueMs,
                min: 0,
                max: maxMs,
                onChangeStart: (_) {
                  _dragging = true;
                  _showOverlayTemporarily();
                },
                // While dragging only the handle moves; no seek yet.
                onChanged: (v) {
                  setState(
                          () => _position = Duration(milliseconds: v.round()));
                },
                // The real seek happens when the finger is lifted.
                onChangeEnd: (v) {
                  _dragging = false;
                  _seekTo(Duration(milliseconds: v.round()));
                  _showOverlayTemporarily();
                },
              ),
            ),
          ),
          Text(_fmt(_duration),
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Overlay / lifecycle
  // ------------------------------------------------------------

  void _showOverlayTemporarily() {
    _overlayTimer?.cancel();

    if (!_showOverlay && mounted) {
      setState(() => _showOverlay = true);
    }

    _overlayTimer = Timer(
      const Duration(seconds: 4),
          () {
        if (mounted) {
          setState(() => _showOverlay = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _controller?.dispose(forceDispose: true);
    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  Widget _buildVideo() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return SizedBox.expand(
      child: BetterPlayer(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        // CHANGE [4]: REPLACED the old onKeyEvent. The old one only showed
        // the overlay on a key press. This one still does that, and ALSO,
        // for movies only (_isSeekable), handles:
        //   Right arrow      -> forward 10 seconds
        //   Left arrow       -> back 10 seconds
        //   OK/Enter/Play    -> pause / resume
        // For live TV _isSeekable is false, so behaviour is unchanged.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            _showOverlayTemporarily();

            if (_isSeekable) {
              final key = event.logicalKey;

              if (key == LogicalKeyboardKey.arrowRight) {
                _seekBy(const Duration(seconds: 10));
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft) {
                _seekBy(const Duration(seconds: -10));
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  (key == LogicalKeyboardKey.enter ||
                      key == LogicalKeyboardKey.select ||
                      key == LogicalKeyboardKey.mediaPlayPause)) {
                _togglePlayPause();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showOverlayTemporarily,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!_channelNotFound) _buildVideo(),

              if (_channelNotFound)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Channel not available now',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorText!,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              if (!_channelNotFound && (_isLoading || _isBuffering))
                const Center(
                  child: CircularProgressIndicator(),
                ),

              AnimatedOpacity(
                opacity: _showOverlay ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showOverlay,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black87,
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // CHANGE [5] (FIX B, 2nd version): the seek bar. Only added
              // for movies (_isSeekable). It is now placed with an explicit
              // `Positioned`, at the bottom edge of the 16:9 video, instead
              // of `Align`, which put it in the middle of the picture.
              if (_isSeekable)
                LayoutBuilder(
                  builder: (context, constraints) {
                    // The video is 16:9 and centred. On a phone held upright
                    // that leaves black space above and below it, so the bar
                    // is lifted to sit on the bottom edge of the picture.
                    // On a TV (16:9 screen) the offset is 0.
                    final videoHeight = (constraints.maxWidth * 9 / 16)
                        .clamp(0.0, constraints.maxHeight)
                        .toDouble();
                    final bottom = (constraints.maxHeight - videoHeight) / 2;

                    return Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: bottom,
                          child: AnimatedOpacity(
                            opacity: _showOverlay ? 1 : 0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: !_showOverlay,
                              child: _buildSeekBar(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}