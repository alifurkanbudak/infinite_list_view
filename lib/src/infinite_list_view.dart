import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:infinite_list_view/src/infinite_scroll_physics.dart';
import 'package:infinite_list_view/src/visibility_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'infinite_loader.dart';

class InfiniteListView<PageKeyType, ItemType> extends StatefulWidget {
  const InfiniteListView({
    required GlobalKey<InfiniteListViewState<PageKeyType, ItemType>> key,
    required this.initialPageKey,
    required this.requestPage,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.autoScrollThreshold = 50,
    this.autoScrollStateChange,
    this.maxAutoScrollDuration = 200,
    this.pageRequestThreshold = 100,
    this.loaderSize = 20,
    this.androidLoaderStrokeWidth = 2,
    this.loaderSpacing = 4,
    this.padding = EdgeInsets.zero,
    this.androidLoaderColor,
    this.onVisibilityChange,
  }) : super(key: key);

  final PageKeyType initialPageKey;

  final FutureOr<void> Function(PageKeyType pageKey) requestPage;

  final Widget Function(
    BuildContext context,
    int index,
  ) itemBuilder;

  final Widget Function(
    BuildContext context,
    int index,
  ) separatorBuilder;

  final void Function(int minInd, int maxInd)? onVisibilityChange;

  final EdgeInsets padding;

  /// In pixels
  final double autoScrollThreshold;

  final void Function(bool inAutoScrollRegion)? autoScrollStateChange;

  /// In milliseconds
  final int maxAutoScrollDuration;

  /// In pixels
  final double pageRequestThreshold;

  final double loaderSize;

  final double androidLoaderStrokeWidth;

  final Color? androidLoaderColor;

  // Top and bottom margin of the indicator
  final double loaderSpacing;

  @override
  State<InfiniteListView> createState() =>
      InfiniteListViewState<PageKeyType, ItemType>();
}

class InfiniteListViewState<PageKeyType, ItemType>
    extends State<InfiniteListView<PageKeyType, ItemType>> {
  late final _visibilityCtrlr = VisibilityController(
    onVisibilityChange: _onVisibilityChange,
  );

  late PageKeyType _pageKey = widget.initialPageKey;

  UnmodifiableListView<ItemType> get items => _items;
  UnmodifiableListView<ItemType> _items = UnmodifiableListView([]);

  static const _isReverse = true;

  bool _isFetching = false;
  bool _isLastPageFetched = false;

  final _loaderKey = GlobalKey<InfiniteLoaderState>();

  final _scrollCtrlr = ScrollController();
  final _scrollPhysics = InfiniteScrollPhysics(
    state: InfiniteScrollPhysicsState(),
  );

  int _autoScrollCalls = 0;
  bool _inAutoScrollRegion = true;

  @override
  void initState() {
    super.initState();

    _scrollCtrlr.addListener(_handleScrollChange);
    _requestPage();
  }

  @override
  void dispose() {
    _scrollCtrlr.dispose();

    super.dispose();
  }

  void addPage({
    required List<ItemType> pageItems,
    required PageKeyType pageKey,
    required bool isLastPage,
  }) {
    debugPrint('InfiniteListView. addPage...');
    _visibilityCtrlr.pageAdded(pageItems.length);
    _pageKey = pageKey;

    setState(() {
      _isLastPageFetched = isLastPage;
      _isFetching = false;
      _items = UnmodifiableListView([
        ...pageItems.reversed,
        ..._items,
      ]);
    });

    if (pageItems.isNotEmpty) HapticFeedback.mediumImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScrollCalls > 0) _autoScrollToBottom();
    });
  }

  /// Returns true if the list auto scrolled to view new messages
  bool addNewItems({required List<ItemType> items}) {
    debugPrint('InfiniteListView. addNewItems...');

    final autoScroll = _autoScrollCalls > 0 ||
        _scrollDistToBottom() <= widget.autoScrollThreshold;

    _scrollPhysics.keepNextScroll();

    setState(() {
      _items = UnmodifiableListView([
        ..._items,
        ...items.reversed,
      ]);
    });

    if (autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoScrollToBottom();
      });
    }

    return autoScroll;
  }

  /// Optimally shouldn't cause size change
  void updateItem({required int index, required ItemType item}) {
    debugPrint('InfiniteListView. updateItem...');
    setState(() {
      _items = UnmodifiableListView([
        for (int i = 0; i < _items.length; i++) i == index ? item : _items[i]
      ]);
    });
  }

  void onError(Object error) {
    debugPrint('InfiniteListView. onError...');
    setState(() {
      _isFetching = false;
    });
  }

  void scrollToBottom() {
    _autoScrollToBottom();
  }

  void _onVisibilityChange(int minInd, int maxInd) {
    if (!mounted) return;

    widget.onVisibilityChange?.call(minInd, maxInd);

    if (minInd < 4) _requestPage();
  }

  void _handleScrollChange() {
    // debugPrint('InfiniteListView. _handleScrollChange offset: $offset');

    _autoScrollRegionUpdate();
  }

  void _autoScrollRegionUpdate() {
    final newAutoScrollState =
        _scrollDistToBottom() <= widget.autoScrollThreshold;
    final oldAutoScrollState = _inAutoScrollRegion;

    _inAutoScrollRegion = newAutoScrollState;

    if (oldAutoScrollState != newAutoScrollState) {
      widget.autoScrollStateChange?.call(newAutoScrollState);
    }
  }

  void _requestPage() {
    if (_isFetching || _isLastPageFetched) return;
    setState(() => _isFetching = true);

    widget.requestPage(_pageKey);
  }

  Future<void> _autoScrollToBottom() async {
    _autoScrollCalls += 1;

    final duration = math
        .min(
          widget.maxAutoScrollDuration,
          math.max(0, _scrollDistToBottom() * 2.5),
        )
        .toInt(); // ms

    await _scrollCtrlr.animateTo(
      _bottomScrollOffset(),
      duration: Duration(milliseconds: duration),
      curve: Curves.linear,
    );

    _autoScrollCalls = math.max(0, _autoScrollCalls - 1);
  }

  double _bottomScrollOffset() =>
      _isReverse ? 0 : _scrollCtrlr.position.maxScrollExtent;

  double _scrollDistToBottom() => _isReverse
      ? _scrollCtrlr.offset
      : _scrollCtrlr.position.maxScrollExtent - _scrollCtrlr.offset;

  bool _onUserScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.forward) {
      _autoScrollCalls = 0;
    }

    return false;
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final adjustedInd = _isReverse ? _items.length - index - 1 : index;

    Widget itemWidget = VisibilityDetector(
      key: ObjectKey(_items[adjustedInd]),
      onVisibilityChanged: (info) => _visibilityCtrlr.updateItemVisibility(
        info: info,
        index: adjustedInd,
      ),
      child: widget.itemBuilder(context, adjustedInd),
    );

    if (adjustedInd < _items.length - 1) {
      itemWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          itemWidget,
          widget.separatorBuilder(context, adjustedInd),
        ],
      );
    }

    return itemWidget;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('InfiniteListView. build...');
    double listTopPadding = _isLastPageFetched
        ? widget.padding.top
        : math.max(
            widget.loaderSize + widget.loaderSpacing * 2,
            widget.padding.top,
          );

    Widget listView = CustomScrollView(
      controller: _scrollCtrlr,
      reverse: _isReverse,
      slivers: [
        SliverPadding(
          padding: widget.padding.copyWith(top: listTopPadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              _itemBuilder,
              childCount: _items.length,
            ),
          ),
        ),
      ],
    );

    // Widget listView = ListView.builder(
    //   controller: _scrollCtrlr,
    //   itemCount: _items.length,
    //   shrinkWrap: _isReverse,
    //   padding: widget.padding.copyWith(top: listTopPadding),
    //   reverse: _isReverse,
    //   itemBuilder: _itemBuilder,
    // );

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (_items.isNotEmpty)
          InfiniteLoader(
            key: _loaderKey,
            isFetching: _isFetching,
            spacing: widget.loaderSpacing,
            size: widget.loaderSize,
            androidStrokeWidth: widget.androidLoaderStrokeWidth,
            androidColor: widget.androidLoaderColor,
          ),
        NotificationListener<UserScrollNotification>(
          onNotification: _onUserScrollNotification,
          child: listView,
        ),
      ],
    );
  }
}
