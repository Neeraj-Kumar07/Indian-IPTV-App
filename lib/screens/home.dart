// import 'dart:async';
//
// import 'package:flutter/material.dart';
// import '/screens/player.dart';
// import '../model/channel.dart';
// import '../model/stream_source.dart';
// import '../provider/channels_provider.dart';
//
// class Home extends StatefulWidget {
//   const Home({Key? key}) : super(key: key);
//
//   @override
//   _HomeState createState() => _HomeState();
// }
//
// class _HomeState extends State<Home> {
//   List<Channel> channels = [];
//   List<Channel> filteredChannels = [];
//   List<StreamSource> streamSources = [];
//   StreamSource? selectedSource;
//
//   TextEditingController searchController = TextEditingController();
//
//   // Focus for the search box.
//   final FocusNode _searchFocusNode = FocusNode();
//
//   // Focus nodes for the channel rows.
//   final List<FocusNode> _channelFocusNodes = [];
//
//   final ChannelsProvider channelsProvider = ChannelsProvider();
//
//   bool _isLoading = true;
//   Timer? _debounceTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     fetchStreamSources();
//   }
//
//   Future<void> fetchStreamSources() async {
//     try {
//       final sources = await channelsProvider.fetchStreamSources();
//       setState(() {
//         streamSources = sources;
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('There was a problem loading stream categories'),
//           ),
//         );
//       }
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> fetchChannels(StreamSource source) async {
//     setState(() {
//       _isLoading = true;
//       selectedSource = source;
//       searchController.clear();
//     });
//
//     try {
//       final data = await channelsProvider.fetchM3UFile(source.streamUrl);
//       setState(() {
//         channels = data;
//         filteredChannels = data;
//         _isLoading = false;
//       });
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('There was a problem loading channels'),
//           ),
//         );
//       }
//       setState(() {
//         selectedSource = null;
//         _isLoading = false;
//       });
//     }
//   }
//
//   void backToCategories() {
//     setState(() {
//       selectedSource = null;
//       channels = [];
//       filteredChannels = [];
//       searchController.clear();
//     });
//   }
//
//   void filterChannels(String query) {
//     if (_debounceTimer != null) {
//       _debounceTimer!.cancel();
//     }
//     _debounceTimer = Timer(const Duration(milliseconds: 500), () {
//       final filteredData = channelsProvider.filterChannels(query);
//       setState(() {
//         filteredChannels = filteredData;
//       });
//     });
//   }
//
//   @override
//   void dispose() {
//     _debounceTimer?.cancel();
//     searchController.dispose();
//     super.dispose();
//   }
//
//   // @override
//   // Widget build(BuildContext context) {
//   //   if (_isLoading) {
//   //     return const Center(child: CircularProgressIndicator());
//   //   }
//   //
//   //   if (selectedSource == null) {
//   //     return _buildCategoryList();
//   //   }
//   //
//   //   return _buildChannelList();
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       // Only allow the app to close when we're on the category (stream) page
//       canPop: selectedSource == null,
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//         // Back pressed while inside a channel list: go to categories instead
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
//
//     if (selectedSource == null) {
//       return _buildCategoryList();
//     }
//
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
//             ),
//             onPressed: () => fetchChannels(source),
//             child: Text(
//               source.name,
//               style: const TextStyle(fontSize: 16),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildChannelList() {
//     return Column(
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
//           child: Row(
//             children: [
//               IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: backToCategories,
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
//         Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: TextField(
//             controller: searchController,
//             onChanged: filterChannels,
//             decoration: const InputDecoration(
//               labelText: 'Search',
//               hintText: 'Search channels...',
//               prefixIcon: Icon(Icons.search),
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ),
//         Expanded(
//           child: filteredChannels.isEmpty
//               ? const Center(child: Text('No channels found'))
//               : ListView.builder(
//                   itemCount: filteredChannels.length,
//                   itemBuilder: (context, index) {
//                     return ListTile(
//                       leading: Image.network(
//                         filteredChannels[index].logoUrl,
//                         width: 50,
//                         height: 50,
//                         fit: BoxFit.contain,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Image.asset(
//                             'assets/images/tv-icon.png',
//                             width: 50,
//                             height: 50,
//                             fit: BoxFit.contain,
//                           );
//                         },
//                       ),
//                       title: Text(filteredChannels[index].name),
//                       onTap: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => Player(
//                               channel: filteredChannels[index],
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 ),
//         ),
//       ],
//     );
//   }
// }


////////////////////////////////////////////////////

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
//   const Home({Key? key}) : super(key: key);
//
//   @override
//   _HomeState createState() => _HomeState();
// }
//
// class _HomeState extends State<Home> {
//   // Height of one channel row (including margin). Fixed so we can
//   // calculate scroll offsets for off-screen rows.
//   static const double _itemExtent = 88;
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
//       final extra =
//       _channelFocusNodes.sublist(filteredChannels.length);
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
//                   return Theme.of(context).colorScheme.primary.withValues(alpha: 0.35);
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
//               hintText: 'Search channels...',
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
//                       color:
//                       node.hasFocus ? primary : Colors.transparent,
//                       width: 3,
//                     ),
//                     color: node.hasFocus
//                         ? primary.withValues(alpha: 0.10)
//                         : Colors.transparent,
//                   ),
//                   // ExcludeFocus: ListTile must not steal focus
//                   // from the row's own Focus node.
//                   child: ExcludeFocus(
//                     child: ListTile(
//                       leading: Image.network(
//                         channel.logoUrl,
//                         width: 64,
//                         height: 64,
//                         fit: BoxFit.contain,
//                         errorBuilder: (context, error, stackTrace) {
//                           return Image.asset(
//                             'assets/images/tv-icon.png',
//                             width: 64,
//                             height: 64,
//                             fit: BoxFit.contain,
//                           );
//                         },
//                       ),
//                       title: Text(
//                         channel.name,
//                         style: const TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 8,
//                       ),
//                       onTap: () => _playChannel(index),
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

////////////////////////////////////////////////////

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
  // Height of one channel row (including margin). Fixed so we can
  // calculate scroll offsets for off-screen rows.
  static const double _itemExtent = 88;

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
    final top = index * _itemExtent;
    final bottom = top + _itemExtent;
    final offset = position.pixels;
    final viewport = position.viewportDimension;

    double? target;
    if (top < offset) {
      target = top;
    } else if (bottom > offset + viewport) {
      target = bottom - viewport;
    }

    if (target != null) {
      _scrollController.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  void _focusChannel(int index) {
    if (index < 0 || index >= _channelFocusNodes.length) return;

    // 1. Scroll so the row gets built.
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

  // Channel row: UP / DOWN / OK
  KeyEventResult _handleChannelKey(int index, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowUp) {
        if (index == 0) {
          _searchFocusNode.requestFocus();
        } else {
          _focusChannel(index - 1);
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        if (index + 1 < _channelFocusNodes.length) {
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
              hintText: 'Search channels...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),

        // CHANNELS
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No channels found'))
              : ListView.builder(
            controller: _scrollController,
            itemExtent: _itemExtent,
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) {
              if (index >= _channelFocusNodes.length) {
                return const SizedBox.shrink();
              }

              final channel = filteredChannels[index];
              final node = _channelFocusNodes[index];

              return Focus(
                focusNode: node,
                onFocusChange: (_) {
                  if (mounted) setState(() {});
                },
                onKeyEvent: (n, event) =>
                    _handleChannelKey(index, n, event),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: node.hasFocus ? primary : Colors.transparent,
                      width: 3,
                    ),
                    color: node.hasFocus
                        ? primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                  ),
                  // ExcludeFocus: ListTile must not steal focus
                  // from the row's own Focus node.
                  child: ExcludeFocus(
                    child: ListTile(
                      leading: Image.network(
                        channel.logoUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/tv-icon.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                      title: Text(
                        channel.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      onTap: () => _playChannel(index),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}