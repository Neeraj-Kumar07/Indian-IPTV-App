

// HOME.DART
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/screens/player.dart';
import '../model/channel.dart';
import '../model/stream_source.dart';
import '../provider/channels_provider.dart';

/// One chip in the filter row under the search bar.
class _GroupFilter {
  final String label;
  final IconData icon;

  /// A channel matches if its group-title contains ANY of these
  /// (case-insensitive). Empty list = show everything ("All").
  final List<String> keywords;

  const _GroupFilter(this.label, this.icon, this.keywords);
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Grid layout. Tile width is flexible (columns are computed from the
  // screen width); height is fixed so scroll offsets can be calculated.
  static const double _tileHeight = 84;
  static const double _spacing = 8;
  static const double _gridPadding = 8;

  static const double _phoneBreakpoint = 600;
  static const int _tvColumns = 3;
  int _columns = 1;

  // Filter chips shown under the search bar.
  static const List<_GroupFilter> _groups = [
    _GroupFilter('All', Icons.grid_view_rounded, []),
    _GroupFilter('Sports', Icons.sports_cricket_rounded, ['sport']),
    _GroupFilter(
        'Entertainment', Icons.theater_comedy_rounded, ['entertain']),
    _GroupFilter('Movies', Icons.movie_rounded, ['movie', 'cinema']),
    _GroupFilter('News', Icons.newspaper_rounded, ['news']),
    _GroupFilter('Devotional', Icons.temple_hindu_rounded,
        ['devotion', 'religio', 'spirit']),
    _GroupFilter(
        'Kids', Icons.face_rounded, ['kid', 'cartoon', 'children']),
  ];
  int _selectedGroup = 0;

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
  final List<FocusNode> _chipFocusNodes =
  List.generate(_groups.length, (_) => FocusNode());

  // ------------------------------------------------------------
  // INIT
  // ------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _searchFocusNode.onKeyEvent = _handleSearchKey;
    _backFocusNode.onKeyEvent = _handleBackKey;

    fetchStreamSources();
  }

  // ------------------------------------------------------------
  // FOCUS NODE MANAGEMENT
  // ------------------------------------------------------------

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

    _ensureVisible(index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index < _channelFocusNodes.length) {
        _channelFocusNodes[index].requestFocus();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _focusChips() => _chipFocusNodes[_selectedGroup].requestFocus();

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
      _selectedGroup = 0;
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
      _selectedGroup = 0;
      searchController.clear();
    });
  }

  // ------------------------------------------------------------
  // SEARCH + GROUP FILTER
  // ------------------------------------------------------------

  /// Applies the search text AND the selected chip to the loaded channels.
  void _applyFilters() {
    final query = searchController.text.trim();
    List<Channel> list =
    query.isEmpty ? channels : channelsProvider.filterChannels(query);

    final keywords = _groups[_selectedGroup].keywords;
    if (keywords.isNotEmpty) {
      list = list.where((c) {
        final g = (c.groupTitle ?? '').toLowerCase();
        return keywords.any(g.contains);
      }).toList();
    }

    setState(() {
      filteredChannels = list;
      _updateChannelFocusNodes();
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void filterChannels(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _applyFilters();
    });
  }

  void _selectGroup(int i) {
    if (i == _selectedGroup) return;
    _debounceTimer?.cancel();
    setState(() => _selectedGroup = i);
    _applyFilters();
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

  // Search: UP -> back arrow, DOWN -> chips, OK -> first channel
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowUp) {
        _backFocusNode.requestFocus();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        _focusChips();
        return KeyEventResult.handled;
      }

      if (_isSelectKey(key) && _channelFocusNodes.isNotEmpty) {
        _focusChannel(0);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // Chip: LEFT / RIGHT move, UP -> search, DOWN -> grid, OK -> select
  KeyEventResult _handleChipKey(int i, FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.arrowLeft) {
        if (i > 0) _chipFocusNodes[i - 1].requestFocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        if (i < _chipFocusNodes.length - 1) {
          _chipFocusNodes[i + 1].requestFocus();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        if (_channelFocusNodes.isNotEmpty) _focusChannel(0);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && _isSelectKey(key)) {
        _selectGroup(i);
        return KeyEventResult.handled;
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
          _focusChips(); // top row -> chips
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
    for (final node in _chipFocusNodes) {
      node.dispose();
    }
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
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Color.alphaBlend(
                Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.55),
                Theme.of(context).colorScheme.surface,
              ),
            ],
          ),
        ),
        child: _buildBody(),
      ),
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

    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < _phoneBreakpoint;
        final columns = isPhone ? 1 : 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a category',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${streamSources.length} categories  \u2022  pick one to start watching',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: isPhone ? 96 : 140,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: streamSources.length,
                itemBuilder: (context, index) {
                  final source = streamSources[index];
                  return _CategoryCard(
                    name: source.name,
                    index: index,
                    autofocus: index == 0,
                    onTap: () => fetchChannels(source),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChannelList() {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;

    return Column(
      children: [
        // TOP BAR: back button, category title, channel count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              IconButton.filledTonal(
                focusNode: _backFocusNode,
                icon: const Icon(Icons.arrow_back_rounded),
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedSource!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${filteredChannels.length} channels',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        // SEARCH
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: TextField(
            focusNode: _searchFocusNode,
            controller: searchController,
            onChanged: filterChannels,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search by name, ID or group...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerLowest,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: primary, width: 2.5),
              ),
            ),
          ),
        ),

        // GROUP FILTER CHIPS
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              for (int i = 0; i < _groups.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                _buildGroupChip(i),
              ],
            ],
          ),
        ),

        // CHANNELS
        Expanded(
          child: filteredChannels.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('No channels found',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              _columns = constraints.maxWidth < _phoneBreakpoint
                  ? 1
                  : _tvColumns;

              return GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(_gridPadding),
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
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

  // One pill in the filter row. Selected = filled purple, otherwise
  // outlined. Focus (D-pad) = thicker border + slight scale.
  Widget _buildGroupChip(int i) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final group = _groups[i];
    final node = _chipFocusNodes[i];
    final selected = i == _selectedGroup;
    final focused = node.hasFocus;

    final fg = selected ? scheme.onPrimary : scheme.onSurface;

    return Focus(
      focusNode: node,
      onFocusChange: (hasFocus) {
        if (hasFocus && node.context != null) {
          Scrollable.ensureVisible(
            node.context!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 150),
          );
        }
        if (mounted) setState(() {});
      },
      onKeyEvent: (n, event) => _handleChipKey(i, n, event),
      child: AnimatedScale(
        scale: focused ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: selected ? primary : scheme.surfaceContainerLowest,
            border: Border.all(
              color: focused
                  ? primary
                  : (selected ? primary : scheme.outlineVariant),
              width: focused ? 3 : 1.5,
            ),
            boxShadow: focused
                ? [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ]
                : null,
          ),
          child: ExcludeFocus(
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => _selectGroup(i),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(group.icon, size: 22, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      group.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Small rounded label used for the ID and group on each tile.
  Widget _chip(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildChannelTile(int index, Color primary) {
    final channel = filteredChannels[index];
    final node = _channelFocusNodes[index];
    final scheme = Theme.of(context).colorScheme;
    final focused = node.hasFocus;

    final hasId = channel.tvgId != null && channel.tvgId!.isNotEmpty;
    final hasGroup =
        channel.groupTitle != null && channel.groupTitle!.isNotEmpty;

    return Focus(
      focusNode: node,
      onFocusChange: (_) {
        if (mounted) setState(() {});
      },
      onKeyEvent: (n, event) => _handleChannelKey(index, n, event),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: focused
              ? Color.alphaBlend(primary.withValues(alpha: 0.10),
              scheme.surfaceContainerLowest)
              : scheme.surfaceContainerLowest,
          border: Border.all(
            color: focused
                ? primary
                : scheme.outlineVariant.withValues(alpha: 0.7),
            width: focused ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: focused
                  ? primary.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: focused ? 14 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ExcludeFocus(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _playChannel(index),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 64,
                    child: channel.logoUrl.startsWith('http')
                        ? Image.network(
                      channel.logoUrl,
                      fit: BoxFit.contain,
                      headers: const {
                        'User-Agent':
                        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                            'Logo failed: ${channel.logoUrl} -> $error');
                        return Image.asset('assets/images/tv-icon.png',
                            fit: BoxFit.contain);
                      },
                    )
                        : Image.asset(channel.logoUrl, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(
                              child: _chip(
                                'ID: ${channel.displayId}',
                                bg: hasId
                                    ? primary.withValues(alpha: 0.12)
                                    : scheme.surfaceContainerHigh,
                                fg: hasId ? primary : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: _chip(
                                channel.displayGroup,
                                bg: hasGroup
                                    ? scheme.secondaryContainer
                                    : scheme.surfaceContainerHigh,
                                fg: hasGroup
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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

// ------------------------------------------------------------
// CATEGORY CARD
// ------------------------------------------------------------

class _CategoryCard extends StatefulWidget {
  final String name;
  final int index;
  final bool autofocus;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.index,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _focused = false;

  static const List<List<Color>> _gradients = [
    [Color(0xFFEADDFF), Color(0xFFD0BCFF)], // lavender
    [Color(0xFFFFD9E2), Color(0xFFFFBFA8)], // blush -> peach
    [Color(0xFFCDF3E6), Color(0xFFA3E3CE)], // mint
    [Color(0xFFD6EAFF), Color(0xFFADD3FF)], // sky
    [Color(0xFFFFF1C9), Color(0xFFFFD7A8)], // butter -> apricot
    [Color(0xFFF8DAF6), Color(0xFFFFC4DD)], // lilac -> rose
  ];

  static const List<Color> _inks = [
    Color(0xFF4F378B),
    Color(0xFF8C1D40),
    Color(0xFF00513F),
    Color(0xFF0B4A8A),
    Color(0xFF7A4B00),
    Color(0xFF74246E),
  ];

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('my')) return Icons.star_rounded;
    if (n.contains('entertain')) return Icons.theater_comedy_rounded;
    if (n.contains('news')) return Icons.newspaper_rounded;
    if (n.contains('sport')) return Icons.sports_cricket_rounded;
    if (n.contains('movie')) return Icons.movie_rounded;
    if (n.contains('music')) return Icons.music_note_rounded;
    if (n.contains('kid')) return Icons.child_care_rounded;
    if (n.contains('indian')) return Icons.flag_rounded;
    if (n.contains('live')) return Icons.sensors_rounded;
    if (n.contains('every')) return Icons.apps_rounded;
    return Icons.live_tv_rounded;
  }

  Widget _bubble(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[widget.index % _gradients.length];
    final ink = _inks[widget.index % _inks.length];
    final ringColor = ink;

    return AnimatedScale(
      scale: _focused ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _focused ? ringColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: _focused ? 0.8 : 0.4),
              blurRadius: _focused ? 24 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              Positioned(right: -30, top: -40, child: _bubble(130, 0.35)),
              Positioned(right: 50, bottom: -60, child: _bubble(110, 0.28)),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    autofocus: widget.autofocus,
                    onTap: widget.onTap,
                    onFocusChange: (v) => setState(() => _focused = v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            child: Icon(_iconFor(widget.name),
                                color: ink, size: 34),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Browse channels',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: ink.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: ink, size: 22),
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





