// import 'package:chewie/chewie.dart';
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
// import '../model/channel.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';
//
// class Player extends StatefulWidget {
//   final Channel channel;
//
//   Player({required this.channel});
//
//   @override
//   _PlayerState createState() => _PlayerState();
// }
//
// class _PlayerState extends State<Player> {
//   late VideoPlayerController videoPlayerController;
//   late ChewieController chewieController;
//   bool _isLoading = true;
//   bool _channelNotFound = false;
//
//   @override
//   void initState() {
//     super.initState();
//     videoPlayerController =
//         VideoPlayerController.networkUrl(Uri.parse(widget.channel.streamUrl))
//           ..initialize().then((_) {
//             setState(() {
//               _isLoading = false;
//             });
//           }).catchError((error) {
//             setState(() {
//               _isLoading = false;
//               _channelNotFound = true;
//             });
//           });
//
//     chewieController = ChewieController(
//       videoPlayerController: videoPlayerController,
//       autoInitialize: true,
//       isLive: true,
//       autoPlay: true,
//       aspectRatio: 3 / 2,
//       showOptions: false,
//       customControls: const MaterialDesktopControls(
//         showPlayButton: false,
//       ),
//     );
//
//     // Enable wake lock when video starts playing
//     videoPlayerController.addListener(() {
//       if (videoPlayerController.value.isPlaying) {
//         WakelockPlus.enable();
//       }
//     });
//
//     // Disable wake lock when video stops
//     videoPlayerController.addListener(() {
//       if (!videoPlayerController.value.isPlaying) {
//         WakelockPlus.disable();
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     videoPlayerController.dispose();
//     chewieController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.channel.name),
//       ),
//       body: Center(
//         child: _isLoading
//             ? const CircularProgressIndicator()
//             : _channelNotFound
//                 ? const Text('Channel not available now',
//                     style: TextStyle(fontSize: 24.0))
//                 : SizedBox(
//                     height: MediaQuery.of(context).size.height * 0.5,
//                     child: Chewie(
//                       controller: chewieController,
//                     ),
//                   ),
//       ),
//     );
//   }
// }


///////2323//////////////////////////////////////////////
//
// import 'dart:async';
//
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:video_player/video_player.dart';
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
//   late final VideoPlayerController _controller;
//
//   bool _isLoading = true;
//   bool _channelNotFound = false;
//   bool _showOverlay = true;
//
//   Timer? _overlayTimer;
//   // Tell ExoPlayer which format the stream is (DASH for .mpd, HLS for .m3u8).
//   VideoFormat? _formatFor(String url) {
//     final u = url.toLowerCase();
//     if (u.contains('.mpd')) return VideoFormat.dash;
//     if (u.contains('.m3u8')) return VideoFormat.hls;
//     return null; // anything else: let the player detect it
//   }
//   @override
//   void initState() {
//     super.initState();
//
//     SystemChrome.setEnabledSystemUIMode(
//       SystemUiMode.immersiveSticky,
//     );
//
//     WakelockPlus.enable();
//
//     // _controller = VideoPlayerController.networkUrl(
//     //   Uri.parse(widget.channel.streamUrl),
//     //   httpHeaders: widget.channel.httpHeaders ?? const {},
//     // );
//     _controller = VideoPlayerController.networkUrl(
//       Uri.parse(widget.channel.streamUrl),
//       formatHint: _formatFor(widget.channel.streamUrl),
//       httpHeaders: widget.channel.httpHeaders ?? const {},
//     );
//
//     _initPlayer();
//     _showOverlayTemporarily();
//   }
//
//   Future<void> _initPlayer() async {
//     try {
//       await _controller.initialize();
//
//       if (!mounted) return;
//
//       // Browsers block autoplay with sound, so start muted on web only.
//       await _controller.setVolume(kIsWeb ? 0.0 : 1.0);
//
//       await _controller.play();
//
//       setState(() {
//         _isLoading = false;
//       });
//     // } catch (_) {
//     } catch (e) {
//       debugPrint('Player error for ${widget.channel.streamUrl}: $e');
//       if (!mounted) return;
//
//       setState(() {
//         _isLoading = false;
//         _channelNotFound = true;
//       });
//     }
//   }
//
//   void _showOverlayTemporarily() {
//     _overlayTimer?.cancel();
//
//     if (!_showOverlay) {
//       setState(() {
//         _showOverlay = true;
//       });
//     }
//
//     _overlayTimer = Timer(
//       const Duration(seconds: 4),
//           () {
//         if (mounted) {
//           setState(() {
//             _showOverlay = false;
//           });
//         }
//       },
//     );
//   }
//
//   @override
//   void dispose() {
//     _overlayTimer?.cancel();
//
//     _controller.dispose();
//
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
//   // ------------------------------------------------------------
//   // VIDEO DISPLAY
//   // ------------------------------------------------------------
//   //
//   // IMPORTANT:
//   //
//   // We deliberately use BoxFit.fill.
//   //
//   // Why?
//   //
//   // BoxFit.cover:
//   //   - 16:9 = good
//   //   - 4:3  = crops top/bottom
//   //
//   // BoxFit.contain:
//   //   - keeps entire picture
//   //   - creates black bars
//   //
//   // BoxFit.fill:
//   //   - entire picture remains visible
//   //   - fills the complete 16:9 TV
//   //   - 4:3 channels are horizontally stretched
//   //
//   // This matches the requested behavior:
//   // "no crop + no black side bars + full 16:9 screen".
//   //
//   Widget _buildVideo() {
//     final size = _controller.value.size;
//
//     final videoWidth =
//     size.width > 0 ? size.width : 1920.0;
//
//     final videoHeight =
//     size.height > 0 ? size.height : 1080.0;
//
//     return SizedBox.expand(
//       child: ClipRect(
//         child: FittedBox(
//           fit: BoxFit.fill,
//           clipBehavior: Clip.hardEdge,
//           child: SizedBox(
//             width: videoWidth,
//             height: videoHeight,
//             child: VideoPlayer(_controller),
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//
//       body: Focus(
//         autofocus: true,
//
//         // ------------------------------------------------------
//         // Remote keys
//         // ------------------------------------------------------
//         //
//         // We DO NOT use Up/Down for zoom anymore.
//         //
//         // OK/Enter also no longer changes aspect ratio.
//         //
//         onKeyEvent: (node, event) {
//           if (event is KeyDownEvent) {
//             _showOverlayTemporarily();
//
//             // Back key is intentionally ignored here so that
//             // Android/TV navigation can handle it normally.
//             return KeyEventResult.ignored;
//           }
//
//           return KeyEventResult.ignored;
//         },
//
//         child: GestureDetector(
//           behavior: HitTestBehavior.opaque,
//           onTap: _showOverlayTemporarily,
//
//           child: Stack(
//             fit: StackFit.expand,
//
//             children: [
//               // ------------------------------------------------
//               // Channel unavailable
//               // ------------------------------------------------
//               if (_channelNotFound)
//                 const Center(
//                   child: Text(
//                     'Channel not available now',
//                     style: TextStyle(
//                       fontSize: 24.0,
//                       color: Colors.white,
//                     ),
//                   ),
//                 )
//
//               // ------------------------------------------------
//               // Video
//               // ------------------------------------------------
//               else if (!_isLoading)
//                 _buildVideo(),
//
//               // ------------------------------------------------
//               // Loading spinner
//               // ------------------------------------------------
//               if (_isLoading)
//                 const Center(
//                   child: CircularProgressIndicator(),
//                 )
//
//               // ------------------------------------------------
//               // Buffering spinner
//               // ------------------------------------------------
//               else if (!_channelNotFound)
//                 ValueListenableBuilder<VideoPlayerValue>(
//                   valueListenable: _controller,
//
//                   builder: (context, value, _) {
//                     return value.isBuffering
//                         ? const Center(
//                       child: CircularProgressIndicator(),
//                     )
//                         : const SizedBox.shrink();
//                   },
//                 ),
//
//               // ------------------------------------------------
//               // Top overlay
//               // ------------------------------------------------
//               AnimatedOpacity(
//                 opacity: _showOverlay ? 1.0 : 0.0,
//                 duration: const Duration(
//                   milliseconds: 250,
//                 ),
//
//                 child: IgnorePointer(
//                   ignoring: !_showOverlay,
//
//                   child: Align(
//                     alignment: Alignment.topCenter,
//
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 8,
//                       ),
//
//                       decoration: const BoxDecoration(
//                         gradient: LinearGradient(
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//
//                           colors: [
//                             Colors.black87,
//                             Colors.transparent,
//                           ],
//                         ),
//                       ),
//
//                       child: Row(
//                         children: [
//                           // Back button
//                           IconButton(
//                             icon: const Icon(
//                               Icons.arrow_back,
//                               color: Colors.white,
//                             ),
//
//                             onPressed: () {
//                               Navigator.of(context).pop();
//                             },
//                           ),
//
//                           const SizedBox(width: 8),
//
//                           // Channel name
//                           Expanded(
//                             child: Text(
//                               widget.channel.name,
//
//                               maxLines: 1,
//
//                               overflow:
//                               TextOverflow.ellipsis,
//
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
// /////////////////2323/////////////////////////////////




// (Your old commented-out Chewie code at the top of the file can stay
//  here unchanged. It is only comments, so it has no effect.)

///////2323//////////////////////////////////////////////

import 'dart:async';

// REMOVED: import 'package:flutter/foundation.dart' show kIsWeb;
// (it was only used for the web-muting line, which no longer exists)
import 'package:flutter/foundation.dart' show debugPrint; // NEW: needed for debugPrint
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// REMOVED: import 'package:video_player/video_player.dart';
import 'package:better_player_plus/better_player_plus.dart'; // NEW: replaces video_player
import 'package:wakelock_plus/wakelock_plus.dart';

import '../model/channel.dart';

class Player extends StatefulWidget {
  final Channel channel;

  const Player({super.key, required this.channel});

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  // CHANGED: was `late final VideoPlayerController _controller;`
  late final BetterPlayerController _controller;

  bool _isLoading = true;
  bool _isBuffering = false; // NEW: buffering state now comes from player events
  bool _channelNotFound = false;
  bool _showOverlay = true;

  Timer? _overlayTimer;

  // CHANGED: was `VideoFormat? _formatFor(...)` returning video_player's
  // VideoFormat. Now it returns better_player_plus's BetterPlayerVideoFormat.
  BetterPlayerVideoFormat _formatFor(String url) {
    final u = url.toLowerCase();
    if (u.contains('.mpd')) return BetterPlayerVideoFormat.dash; // DASH
    if (u.contains('.m3u8')) return BetterPlayerVideoFormat.hls; // HLS
    return BetterPlayerVideoFormat.other; // anything else: let the player detect it
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    WakelockPlus.enable();

    // REMOVED: the old VideoPlayerController.networkUrl(...) creation
    // (both the commented one and the formatHint one).

    // NEW: describe the stream (URL, headers, format).
    final url = widget.channel.streamUrl;
    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      headers: widget.channel.httpHeaders, // same headers you used before
      videoFormat: _formatFor(url),
      liveStream: true, // these are live TV channels
    );

    // NEW: create the better_player_plus controller.
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true, // replaces `_controller.play()`
        fit: BoxFit.fill, // same "fill the whole 16:9 TV" behaviour as before
        aspectRatio: 16 / 9,
        // Hide better_player_plus's own controls; we use our own overlay.
        controlsConfiguration:
        BetterPlayerControlsConfiguration(showControls: false),
      ),
      betterPlayerDataSource: dataSource,
    );

    // NEW: replaces `_initPlayer()`. The player reports its state through
    // events instead of an `await initialize()` call.
    _controller.addEventsListener((event) {
      if (!mounted) return;

      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
          setState(() => _isLoading = false);
          break;
        case BetterPlayerEventType.bufferingStart:
          setState(() => _isBuffering = true);
          break;
        case BetterPlayerEventType.bufferingEnd:
          setState(() => _isBuffering = false);
          break;
        case BetterPlayerEventType.exception:
        // Prints the real reason in the Android Studio console.
          debugPrint('Player error for $url: ${event.parameters}');
          setState(() {
            _isLoading = false;
            _channelNotFound = true;
          });
          break;
        default:
          break;
      }
    });

    // REMOVED: _initPlayer(); (no longer needed, see event listener above)
    _showOverlayTemporarily();
  }

  // REMOVED: Future<void> _initPlayer() async { ... }
  // It called initialize(), setVolume(), play() and caught errors.
  // better_player_plus does all of that itself (autoPlay + events).

  void _showOverlayTemporarily() {
    _overlayTimer?.cancel();

    if (!_showOverlay) {
      setState(() {
        _showOverlay = true;
      });
    }

    _overlayTimer = Timer(
      const Duration(seconds: 4),
          () {
        if (mounted) {
          setState(() {
            _showOverlay = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();

    // CHANGED: forceDispose is required, otherwise the controller
    // may not actually be released.
    _controller.dispose(forceDispose: true);

    WakelockPlus.disable();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  // ------------------------------------------------------------
  // VIDEO DISPLAY
  // ------------------------------------------------------------
  //
  // CHANGED: the old version wrapped VideoPlayer in FittedBox/SizedBox and
  // read `_controller.value.size`. better_player_plus handles sizing itself
  // using `fit: BoxFit.fill` from the configuration above, so we only
  // need to give it the whole screen.
  //
  // BoxFit.fill (set in BetterPlayerConfiguration):
  //   - entire picture remains visible
  //   - fills the complete 16:9 TV
  //   - 4:3 channels are horizontally stretched
  //
  Widget _buildVideo() {
    return SizedBox.expand(
      child: BetterPlayer(controller: _controller), // CHANGED: was VideoPlayer(_controller)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Focus(
        autofocus: true,

        // ------------------------------------------------------
        // Remote keys (unchanged)
        // ------------------------------------------------------
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            _showOverlayTemporarily();

            // Back key is intentionally ignored here so that
            // Android/TV navigation can handle it normally.
            return KeyEventResult.ignored;
          }

          return KeyEventResult.ignored;
        },

        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showOverlayTemporarily,

          child: Stack(
            fit: StackFit.expand,

            children: [
              // ------------------------------------------------
              // Video
              // ------------------------------------------------
              // CHANGED: the video widget is now shown from the start (not
              // only after loading), because better_player_plus needs to be
              // in the widget tree to start playback.
              if (!_channelNotFound) _buildVideo(),

              // ------------------------------------------------
              // Channel unavailable
              // ------------------------------------------------
              if (_channelNotFound)
                const Center(
                  child: Text(
                    'Channel not available now',
                    style: TextStyle(
                      fontSize: 24.0,
                      color: Colors.white,
                    ),
                  ),
                ),

              // ------------------------------------------------
              // Loading / buffering spinner
              // ------------------------------------------------
              // CHANGED: the old ValueListenableBuilder<VideoPlayerValue>
              // is gone. Both states now use the _isLoading / _isBuffering
              // flags set by the event listener in initState().
              if (!_channelNotFound && (_isLoading || _isBuffering))
                const Center(
                  child: CircularProgressIndicator(),
                ),

              // ------------------------------------------------
              // Top overlay (unchanged)
              // ------------------------------------------------
              AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(
                  milliseconds: 250,
                ),

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
                          // Back button
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

                          // Channel name
                          Expanded(
                            child: Text(
                              widget.channel.name,

                              maxLines: 1,

                              overflow:
                              TextOverflow.ellipsis,

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
/////////////////2323/////////////////////////////////