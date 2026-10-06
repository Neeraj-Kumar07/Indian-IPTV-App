//
//
// ////////////////////////////////////////////////////////////////
//
//
//
// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
//
// import '/screens/player.dart';
// import '../model/channel.dart';
// import '../model/stream_source.dart';
// import '../provider/channels_provider.dart';
//
// class Home extends StatefulWidget {
//   const Home({super.key});
//
//   @override
//   State<Home> createState() => _HomeState();
// }
//
// class _HomeState extends State<Home> {
//   // Height of one channel row (including margin). Fixed so we can
//   // calculate scroll offsets for off-screen rows.
//   // CHANGED: 104 so the 3-line tile (name, ID, group) fits.
//   static const double _itemExtent = 104;
//
//   List<Channel> channels = [];
//   List<Channel> filteredChannels = [];
//   List<StreamSource> streamSources = [];
//   StreamSource? selectedSource;
//
//   final TextEditingController searchController = TextEditingController();
//   final ChannelsProvider channelsProvider = ChannelsProvider();
//   final ScrollController _scrollController = ScrollController();
//
//   Timer? _debounceTimer;
//   bool _isLoading = true;
//
//   final FocusNode _backFocusNode = FocusNode();
//   final FocusNode _searchFocusNode = FocusNode();
//   final List<FocusNode> _channelFocusNodes = [];
//
//   // ------------------------------------------------------------
//   // INIT
//   // ------------------------------------------------------------
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Key handlers attached directly to the nodes so they run BEFORE
//     // the TextField / IconButton consume the key.
//     _searchFocusNode.onKeyEvent = _handleSearchKey;
//     _backFocusNode.onKeyEvent = _handleBackKey;
//
//     fetchStreamSources();
//   }
//
//   // ------------------------------------------------------------
//   // FOCUS NODE MANAGEMENT
//   // ------------------------------------------------------------
//
//   /// Dispose nodes AFTER the current frame, so widgets that are still
//   /// mounted don't try to use a disposed node.
//   void _disposeLater(List<FocusNode> nodes) {
//     if (nodes.isEmpty) return;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       for (final n in nodes) {
//         n.dispose();
//       }
//     });
//   }
//
//   void _updateChannelFocusNodes() {
//     if (_channelFocusNodes.length > filteredChannels.length) {
//       final extra = _channelFocusNodes.sublist(filteredChannels.length);
//       _channelFocusNodes.removeRange(
//           filteredChannels.length, _channelFocusNodes.length);
//       _disposeLater(extra);
//     }
//
//     while (_channelFocusNodes.length < filteredChannels.length) {
//       _channelFocusNodes.add(FocusNode());
//     }
//   }
//
//   void _clearChannelFocusNodes() {
//     final old = List<FocusNode>.from(_channelFocusNodes);
//     _channelFocusNodes.clear();
//     _disposeLater(old);
//   }
//
//   // ------------------------------------------------------------
//   // SCROLL + FOCUS A CHANNEL
//   // ------------------------------------------------------------
//
//   void _ensureVisible(int index) {
//     if (!_scrollController.hasClients) return;
//
//     final position = _scrollController.position;
//     final top = index * _itemExtent;
//     final bottom = top + _itemExtent;
//     final offset = position.pixels;
//     final viewport = position.viewportDimension;
//
//     double? target;
//     if (top < offset) {
//       target = top;
//     } else if (bottom > offset + viewport) {
//       target = bottom - viewport;
//     }
//
//     if (target != null) {
//       _scrollController.jumpTo(
//         target.clamp(position.minScrollExtent, position.maxScrollExtent),
//       );
//     }
//   }
//
//   void _focusChannel(int index) {
//     if (index < 0 || index >= _channelFocusNodes.length) return;
//
//     // 1. Scroll so the row gets built.
//     _ensureVisible(index);
//
//     // 2. Focus it once it exists.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (index < _channelFocusNodes.length) {
//         _channelFocusNodes[index].requestFocus();
//       }
//     });
//     WidgetsBinding.instance.scheduleFrame();
//   }
//
//   // ------------------------------------------------------------
//   // LOAD STREAM CATEGORIES
//   // ------------------------------------------------------------
//
//   Future<void> fetchStreamSources() async {
//     try {
//       final sources = await channelsProvider.fetchStreamSources();
//       if (!mounted) return;
//       setState(() {
//         streamSources = sources;
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('There was a problem loading stream categories'),
//         ),
//       );
//       setState(() => _isLoading = false);
//     }
//   }
//
//   // ------------------------------------------------------------
//   // LOAD CHANNELS
//   // ------------------------------------------------------------
//
//   Future<void> fetchChannels(StreamSource source) async {
//     _searchFocusNode.unfocus();
//     _clearChannelFocusNodes();
//
//     setState(() {
//       _isLoading = true;
//       selectedSource = source;
//       searchController.clear();
//     });
//
//     try {
//       final data = await channelsProvider.fetchM3UFile(source.streamUrl);
//       if (!mounted) return;
//
//       setState(() {
//         channels = data;
//         filteredChannels = data;
//         _isLoading = false;
//         _updateChannelFocusNodes();
//       });
//
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted && _channelFocusNodes.isNotEmpty) {
//           _channelFocusNodes.first.requestFocus();
//         }
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('There was a problem loading channels'),
//         ),
//       );
//       setState(() {
//         selectedSource = null;
//         _isLoading = false;
//       });
//     }
//   }
//
//   // ------------------------------------------------------------
//   // BACK TO CATEGORIES
//   // ------------------------------------------------------------
//
//   void backToCategories() {
//     _debounceTimer?.cancel();
//     _searchFocusNode.unfocus();
//     _clearChannelFocusNodes();
//
//     setState(() {
//       selectedSource = null;
//       channels = [];
//       filteredChannels = [];
//       searchController.clear();
//     });
//   }
//
//   // ------------------------------------------------------------
//   // SEARCH
//   // ------------------------------------------------------------
//
//   // Uses channelsProvider.filterChannels, which now searches
//   // name + tvg-id + group-title (see channels_provider.dart).
//   void filterChannels(String query) {
//     _debounceTimer?.cancel();
//
//     _debounceTimer = Timer(const Duration(milliseconds: 500), () {
//       final filteredData = channelsProvider.filterChannels(query);
//       if (!mounted) return;
//
//       setState(() {
//         filteredChannels = filteredData;
//         _updateChannelFocusNodes();
//       });
//
//       if (_scrollController.hasClients) {
//         _scrollController.jumpTo(0);
//       }
//     });
//   }
//
//   // ------------------------------------------------------------
//   // PLAY
//   // ------------------------------------------------------------
//
//   void _playChannel(int index) {
//     if (index < 0 || index >= filteredChannels.length) return;
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => Player(channel: filteredChannels[index]),
//       ),
//     );
//   }
//
//   // ------------------------------------------------------------
//   // KEY HANDLERS
//   // ------------------------------------------------------------
//
//   bool _isSelectKey(LogicalKeyboardKey key) =>
//       key == LogicalKeyboardKey.enter ||
//           key == LogicalKeyboardKey.select ||
//           key == LogicalKeyboardKey.numpadEnter;
//
//   // Back arrow: DOWN -> search
//   KeyEventResult _handleBackKey(FocusNode node, KeyEvent event) {
//     if (event is KeyDownEvent || event is KeyRepeatEvent) {
//       if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
//         _searchFocusNode.requestFocus();
//         return KeyEventResult.handled;
//       }
//     }
//     return KeyEventResult.ignored;
//   }
//
//   // Search: UP -> back arrow, DOWN -> first channel
//   KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
//     if (event is KeyDownEvent || event is KeyRepeatEvent) {
//       final key = event.logicalKey;
//
//       if (key == LogicalKeyboardKey.arrowUp) {
//         _backFocusNode.requestFocus();
//         return KeyEventResult.handled;
//       }
//
//       if (key == LogicalKeyboardKey.arrowDown || _isSelectKey(key)) {
//         if (_channelFocusNodes.isNotEmpty) {
//           _focusChannel(0);
//           return KeyEventResult.handled;
//         }
//       }
//     }
//     return KeyEventResult.ignored;
//   }
//
//   // Channel row: UP / DOWN / OK
//   KeyEventResult _handleChannelKey(int index, FocusNode node, KeyEvent event) {
//     if (event is KeyDownEvent || event is KeyRepeatEvent) {
//       final key = event.logicalKey;
//
//       if (key == LogicalKeyboardKey.arrowUp) {
//         if (index == 0) {
//           _searchFocusNode.requestFocus();
//         } else {
//           _focusChannel(index - 1);
//         }
//         return KeyEventResult.handled;
//       }
//
//       if (key == LogicalKeyboardKey.arrowDown) {
//         if (index + 1 < _channelFocusNodes.length) {
//           _focusChannel(index + 1);
//         }
//         return KeyEventResult.handled;
//       }
//
//       // Only on key DOWN (not repeat) so holding OK doesn't push twice.
//       if (event is KeyDownEvent && _isSelectKey(key)) {
//         _playChannel(index);
//         return KeyEventResult.handled;
//       }
//     }
//     return KeyEventResult.ignored;
//   }
//
//   // ------------------------------------------------------------
//   // DISPOSE
//   // ------------------------------------------------------------
//
//   @override
//   void dispose() {
//     _debounceTimer?.cancel();
//     searchController.dispose();
//     _scrollController.dispose();
//     _backFocusNode.dispose();
//     _searchFocusNode.dispose();
//     for (final node in _channelFocusNodes) {
//       node.dispose();
//     }
//     _channelFocusNodes.clear();
//     super.dispose();
//   }
//
//   // ------------------------------------------------------------
//   // BUILD
//   // ------------------------------------------------------------
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: selectedSource == null,
//       onPopInvokedWithResult: (bool didPop, Object? result) {
//         if (didPop) return;
//         backToCategories();
//       },
//       child: _buildBody(),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (selectedSource == null) {
//       return _buildCategoryList();
//     }
//     return _buildChannelList();
//   }
//
//   Widget _buildCategoryList() {
//     if (streamSources.isEmpty) {
//       return const Center(child: Text('No stream categories available'));
//     }
//
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: streamSources.length,
//       itemBuilder: (context, index) {
//         final source = streamSources[index];
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 12),
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(vertical: 16),
//             ).copyWith(
//               overlayColor: WidgetStateProperty.resolveWith((states) {
//                 if (states.contains(WidgetState.focused)) {
//                   return Theme.of(context)
//                       .colorScheme
//                       .primary
//                       .withValues(alpha: 0.35);
//                 }
//                 return null;
//               }),
//             ),
//             onPressed: () => fetchChannels(source),
//             child: Text(source.name, style: const TextStyle(fontSize: 18)),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildChannelList() {
//     final primary = Theme.of(context).colorScheme.primary;
//
//     return Column(
//       children: [
//         // TOP BAR
//         Padding(
//           padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
//           child: Row(
//             children: [
//               IconButton(
//                 focusNode: _backFocusNode,
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: backToCategories,
//                 style: ButtonStyle(
//                   side: WidgetStateProperty.resolveWith((states) {
//                     if (states.contains(WidgetState.focused)) {
//                       return BorderSide(color: primary, width: 3);
//                     }
//                     return null;
//                   }),
//                 ),
//               ),
//               Expanded(
//                 child: Text(
//                   selectedSource!.name,
//                   style: Theme.of(context).textTheme.titleMedium,
//                 ),
//               ),
//             ],
//           ),
//         ),
//
//         // SEARCH
//         Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: TextField(
//             focusNode: _searchFocusNode,
//             controller: searchController,
//             onChanged: filterChannels,
//             decoration: const InputDecoration(
//               labelText: 'Search',
//               // CHANGED: hint now mentions ID and group search.
//               hintText: 'Search by name, ID or group...',
//               prefixIcon: Icon(Icons.search),
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//
//         // CHANNELS
//         Expanded(
//           child: filteredChannels.isEmpty
//               ? const Center(child: Text('No channels found'))
//               : ListView.builder(
//             controller: _scrollController,
//             itemExtent: _itemExtent,
//             itemCount: filteredChannels.length,
//             itemBuilder: (context, index) {
//               if (index >= _channelFocusNodes.length) {
//                 return const SizedBox.shrink();
//               }
//
//               final channel = filteredChannels[index];
//               final node = _channelFocusNodes[index];
//
//               return Focus(
//                 focusNode: node,
//                 onFocusChange: (_) {
//                   if (mounted) setState(() {});
//                 },
//                 onKeyEvent: (n, event) =>
//                     _handleChannelKey(index, n, event),
//                 child: Container(
//                   margin: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 2,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(8),
//                     border: Border.all(
//                       color: node.hasFocus ? primary : Colors.transparent,
//                       width: 3,
//                     ),
//                     color: node.hasFocus
//                         ? primary.withValues(alpha: 0.10)
//                         : Colors.transparent,
//                   ),
//                   // ExcludeFocus: the tile must not steal focus
//                   // from the row's own Focus node.
//                   child: ExcludeFocus(
//                     // CHANGED: ListTile replaced with InkWell + Row so the
//                     // tile can show: logo | name (bold) / ID / • group.
//                     child: InkWell(
//                       borderRadius: BorderRadius.circular(8),
//                       onTap: () => _playChannel(index),
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 12,
//                           vertical: 8,
//                         ),
//                         child: Row(
//                           children: [
//                             // CHANGED: logo from tvg-logo; falls back to
//                             // the local TV icon if missing or failing.
//                             SizedBox(
//                               width: 64,
//                               height: 64,
//                               child: channel.logoUrl.startsWith('http')
//                                   ? Image.network(
//                                 channel.logoUrl,
//                                 fit: BoxFit.contain,
//                                 errorBuilder:
//                                     (context, error, stackTrace) =>
//                                     Image.asset(
//                                       'assets/images/tv-icon.png',
//                                       fit: BoxFit.contain,
//                                     ),
//                               )
//                                   : Image.asset(
//                                 channel.logoUrl,
//                                 fit: BoxFit.contain,
//                               ),
//                             ),
//                             const SizedBox(width: 16),
//                             Expanded(
//                               child: Column(
//                                 mainAxisAlignment:
//                                 MainAxisAlignment.center,
//                                 crossAxisAlignment:
//                                 CrossAxisAlignment.start,
//                                 children: [
//                                   // CHANGED: channel name in bold.
//                                   Text(
//                                     channel.name,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                     style: const TextStyle(
//                                       fontSize: 20,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   // CHANGED (new): tvg-id line,
//                                   // "No ID" when missing.
//                                   Text(
//                                     'ID: ${channel.displayId}',
//                                     maxLines: 1,
//                                     style: const TextStyle(fontSize: 15),
//                                   ),
//                                   // CHANGED (new): group-title line,
//                                   // smaller, "No Group" when missing.
//                                   Text(
//                                     '• ${channel.displayGroup}',
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       color: Theme.of(context)
//                                           .colorScheme
//                                           .onSurfaceVariant,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/screens/player.dart';
import '../model/channel.dart';
import '../model/stream_source.dart';
import '../provider/channels_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Grid layout. Tile width is flexible (columns are computed from the
  // screen width); height is fixed so scroll offsets can be calculated.
  static const double _tileHeight = 96;
  static const double _spacing = 8;
  static const double _gridPadding = 8;

  // Screens narrower than this (phones) get 1 column, wider ones (TV,
  // tablet, emulator) get 3. Set from LayoutBuilder in build; used by the
  // key handlers and scroll maths.
  static const double _phoneBreakpoint = 600;
  static const int _tvColumns = 3;
  int _columns = 1;

  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  List<StreamSource> streamSources = [];
  StreamSource? selectedSource;

  final TextEditingController searchController = TextEditingController();
  final ChannelsProvider channelsProvider = ChannelsProvider();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  bool _isLoading = true;

  final FocusNode _backFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final List<FocusNode> _channelFocusNodes = [];

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    // Key handlers attached directly to the nodes so they run BEFORE
    // the TextField / IconButton consume the key.
    _searchFocusNode.onKeyEvent = _handleSearchKey;
    _backFocusNode.onKeyEvent = _handleBackKey;

    fetchStreamSources();
  }

  // ------------------------------------------------------------
  // FOCUS NODE MANAGEMENT
  // ------------------------------------------------------------

  /// Dispose nodes AFTER the current frame, so widgets that are still
  /// mounted don't try to use a disposed node.
  void _disposeLater(List<FocusNode> nodes) {
    if (nodes.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in nodes) {
        n.dispose();
      }
    });
  }

  void _updateChannelFocusNodes() {
    if (_channelFocusNodes.length > filteredChannels.length) {
      final extra = _channelFocusNodes.sublist(filteredChannels.length);
      _channelFocusNodes.removeRange(
          filteredChannels.length, _channelFocusNodes.length);
      _disposeLater(extra);
    }

    while (_channelFocusNodes.length < filteredChannels.length) {
      _channelFocusNodes.add(FocusNode());
    }
  }

  void _clearChannelFocusNodes() {
    final old = List<FocusNode>.from(_channelFocusNodes);
    _channelFocusNodes.clear();
    _disposeLater(old);
  }

  // ------------------------------------------------------------
  // SCROLL + FOCUS A CHANNEL
  // ------------------------------------------------------------

  void _ensureVisible(int index) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final row = index ~/ _columns;
    final top = _gridPadding + row * (_tileHeight + _spacing);
    final bottom = top + _tileHeight;
    final offset = position.pixels;
    final viewport = position.viewportDimension;

    double? target;
    if (top - _gridPadding < offset) {
      target = top - _gridPadding;
    } else if (bottom + _gridPadding > offset + viewport) {
      target = bottom + _gridPadding - viewport;
    }

    if (target != null) {
      _scrollController.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  void _focusChannel(int index) {
    if (index < 0 || index >= _channelFocusNodes.length) return;

    // 1. Scroll so the tile gets built.
    _ensureVisible(index);

    // 2. Focus it once it exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index < _channelFocusNodes.length) {
        _channelFocusNodes[index].requestFocus();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  // ------------------------------------------------------------
  // LOAD STREAM CATEGORIES
  // ------------------------------------------------------------

  Future<void> fetchStreamSources() async {
    try {
      final sources = await channelsProvider.fetchStreamSources();
      if (!mounted) return;
      setState(() {
        streamSources = sources;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem loading stream categories'),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------
  // LOAD CHANNELS
  // ------------------------------------------------------------

  Future<void> fetchChannels(StreamSource source) async {
    _searchFocusNode.unfocus();
    _clearChannelFocusNodes();

    setState(() {
      _isLoading = true;
      selectedSource = source;
      searchController.clear();
    });

    try {
      final data = await channelsProvider.fetchM3UFile(source.streamUrl);
      if (!mounted) return;

      setState(() {
        channels = data;
        filteredChannels = data;
        _isLoading = false;
        _updateChannelFocusNodes();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _channelFocusNodes.isNotEmpty) {
          _channelFocusNodes.first.requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem loading channels'),
        ),
      );
      setState(() {
        selectedSource = null;
        _isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // BACK TO CATEGORIES
  // ------------------------------------------------------------

  void backToCategories() {
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    _clearChannelFocusNodes();

    setState(() {
      selectedSource = null;
      channels = [];
      filteredChannels = [];
      searchController.clear();
    });
  }

  // ------------------------------------------------------------
  // SEARCH
  // ------------------------------------------------------------

  // Uses channelsProvider.filterChannels, which searches
  // name + tvg-id + group-title (see channels_provider.dart).
  void filterChannels(String query) {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final filteredData = channelsProvider.filterChannels(query);
      if (!mounted) return;

      setState(() {
        filteredChannels = filteredData;
        _updateChannelFocusNodes();
      });

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  // ------------------------------------------------------------
  // PLAY
  // ------------------------------------------------------------

  void _playChannel(int index) {
    if (index < 0 || index >= filteredChannels.length) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Player(channel: filteredChannels[index]),
      ),
    );
  }

  // ------------------------------------------------------------
  // KEY HANDLERS
  // ------------------------------------------------------------

  bool _isSelectKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.numpadEnter;

  // Back arrow: DOWN -> search
  KeyEventResult _handleBackKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // Search: UP -> back arrow, DOWN -> first channel
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowUp) {
        _backFocusNode.requestFocus();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowDown || _isSelectKey(key)) {
        if (_channelFocusNodes.isNotEmpty) {
          _focusChannel(0);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  // Channel tile: UP / DOWN / LEFT / RIGHT / OK
  KeyEventResult _handleChannelKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;
      final total = _channelFocusNodes.length;
      final cols = _columns;

      if (key == LogicalKeyboardKey.arrowUp) {
        if (index < cols) {
          _searchFocusNode.requestFocus(); // top row -> search
        } else {
          _focusChannel(index - cols);
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        final next = index + cols;
        if (next < total) {
          _focusChannel(next);
        } else if (index ~/ cols < (total - 1) ~/ cols) {
          // Last row is shorter: go to its last item instead of doing nothing.
          _focusChannel(total - 1);
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowLeft) {
        if (index % cols != 0) _focusChannel(index - 1);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        if ((index + 1) % cols != 0 && index + 1 < total) {
          _focusChannel(index + 1);
        }
        return KeyEventResult.handled;
      }

      // Only on key DOWN (not repeat) so holding OK doesn't push twice.
      if (event is KeyDownEvent && _isSelectKey(key)) {
        _playChannel(index);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    _scrollController.dispose();
    _backFocusNode.dispose();
    _searchFocusNode.dispose();
    for (final node in _channelFocusNodes) {
      node.dispose();
    }
    _channelFocusNodes.clear();
    super.dispose();
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: selectedSource == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        backToCategories();
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (selectedSource == null) {
      return _buildCategoryList();
    }
    return _buildChannelList();
  }

  Widget _buildCategoryList() {
    if (streamSources.isEmpty) {
      return const Center(child: Text('No stream categories available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: streamSources.length,
      itemBuilder: (context, index) {
        final source = streamSources[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.35);
                }
                return null;
              }),
            ),
            onPressed: () => fetchChannels(source),
            child: Text(source.name, style: const TextStyle(fontSize: 18)),
          ),
        );
      },
    );
  }

  Widget _buildChannelList() {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // TOP BAR
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                focusNode: _backFocusNode,
                icon: const Icon(Icons.arrow_back),
                onPressed: backToCategories,
                style: ButtonStyle(
                  side: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.focused)) {
                      return BorderSide(color: primary, width: 3);
                    }
                    return null;
                  }),
                ),
              ),
              Expanded(
                child: Text(
                  selectedSource!.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),

        // SEARCH
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            focusNode: _searchFocusNode,
            controller: searchController,
            onChanged: filterChannels,
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Search by name, ID or group...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // CHANNELS
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No channels found'))
              : LayoutBuilder(
            builder: (context, constraints) {
              _columns = constraints.maxWidth < _phoneBreakpoint
                  ? 1
                  : _tvColumns;

              return GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(_gridPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisExtent: _tileHeight,
                  crossAxisSpacing: _spacing,
                  mainAxisSpacing: _spacing,
                ),
                itemCount: filteredChannels.length,
                itemBuilder: (context, index) {
                  if (index >= _channelFocusNodes.length) {
                    return const SizedBox.shrink();
                  }
                  return _buildChannelTile(index, primary);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChannelTile(int index, Color primary) {
    final channel = filteredChannels[index];
    final node = _channelFocusNodes[index];

    return Focus(
      focusNode: node,
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      onKeyEvent: (n, event) => _handleChannelKey(index, n, event),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          // Focused: bold primary border + tint. Unfocused: soft card.
          border: Border.all(
            color: node.hasFocus
                ? primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: node.hasFocus ? 3 : 1.2,
          ),
          color: node.hasFocus
              ? Color.alphaBlend(
              primary.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surfaceContainerLowest)
              : Theme.of(context).colorScheme.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: node.hasFocus
                  ? primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: node.hasFocus ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // ExcludeFocus: the tile must not steal focus
        // from the Focus node above.
        child: ExcludeFocus(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _playChannel(index),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Logo from tvg-logo; falls back to the local TV icon
                  // if missing or failing.
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: channel.logoUrl.startsWith('http')
                        ? Image.network(
                      channel.logoUrl,
                      fit: BoxFit.contain,
                      // Some logo CDNs reject Dart's default
                      // User-Agent, so send a browser-like one.
                      headers: const {
                        'User-Agent':
                        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Shows the exact reason in the debug console.
                        debugPrint(
                            'Logo failed: ${channel.logoUrl} -> $error');
                        return Image.asset('assets/images/tv-icon.png',
                            fit: BoxFit.contain);
                      },
                    )
                        : Image.asset(channel.logoUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${channel.displayId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15),
                        ),
                        Text(
                          '• ${channel.displayGroup}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}