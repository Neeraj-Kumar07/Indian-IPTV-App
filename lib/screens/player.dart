

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
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            _showOverlayTemporarily();
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
            ],
          ),
        ),
      ),
    );
  }
}