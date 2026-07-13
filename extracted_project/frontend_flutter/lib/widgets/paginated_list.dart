import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend_flutter/widgets/animations.dart';

class PaginatedList<T> extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(int page, int limit) fetchData;
  final Widget Function(T item) itemBuilder;
  final String emptyMessage;
  final String loadingMessage;
  final int initialLimit;
  final Widget? header;
  final bool enableRefresh;

  const PaginatedList({
    super.key,
    required this.fetchData,
    required this.itemBuilder,
    this.emptyMessage = 'No items found',
    this.loadingMessage = 'Loading...',
    this.initialLimit = 20,
    this.header,
    this.enableRefresh = true,
  });

  @override
  State<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<PaginatedList<T>> {
  final ScrollController _scrollController = ScrollController();
  final List<T> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _items.clear();
      _currentPage = 1;
      _hasMoreData = true;
    });

    try {
      final response = await widget.fetchData(1, widget.initialLimit);
      final List<dynamic> data = response['data'] ?? [];
      final bool hasMore = response['hasMore'] ?? false;

      setState(() {
        _items.addAll(data.cast<T>());
        _hasMoreData = hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await widget.fetchData(nextPage, widget.initialLimit);
      final List<dynamic> data = response['data'] ?? [];
      final bool hasMore = response['hasMore'] ?? false;

      setState(() {
        _items.addAll(data.cast<T>());
        _hasMoreData = hasMore;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  Future<void> _refresh() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.loadingMessage),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final child = CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _items.length) {
                // Loading indicator at the end
                if (_isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (!_hasMoreData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No more items to load',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }

              return AppAnimations.fadeIn(
                widget.itemBuilder(_items[index]),
                delay: (index * 50).ms,
              );
            },
            childCount:
                _items.length + (_isLoadingMore || !_hasMoreData ? 1 : 0),
          ),
        ),
      ],
    );

    if (widget.enableRefresh) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      widget.emptyMessage,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : child,
      );
    }

    return _items.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  widget.emptyMessage,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        : child;
  }
}
