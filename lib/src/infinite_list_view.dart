import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:infinite_list_view/src/item_animation.dart';
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
    this.pageRequestThreshold = 3,
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

  /// In number of invisible items above screen
  final int pageRequestThreshold;

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
    isWidgetAlive: () => mounted,
  );

  late PageKeyType _pageKey = widget.initialPageKey;

  UnmodifiableListView<ItemType> get items => _items;
  UnmodifiableListView<ItemType> _items = UnmodifiableListView([]);

  final _itemAnimations = <ItemType, ItemAnimation>{};

  bool _isFetching = false;
  bool _isLastPageFetched = false;

  final _loaderKey = GlobalKey<InfiniteLoaderState>();
  final _animListKey = GlobalKey<AnimatedListState>();

  static const _isReverse = true;
  final _scrollCtrlr = ScrollController();
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

    _items = UnmodifiableListView([
      ...pageItems.reversed,
      ..._items,
    ]);
    _addPagetoAnimList(pageItems);

    setState(() {
      _isLastPageFetched = isLastPage;
      _isFetching = false;
    });

    HapticFeedback.mediumImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScrollCalls > 0) _autoScrollToBottom();
    });
  }

  /// Returns true if the list auto scrolled to view new messages
  bool addNewItems({required List<ItemType> items}) {
    debugPrint('InfiniteListView. addNewItems...');
    final offsetDiff =
        _scrollCtrlr.position.maxScrollExtent - _scrollCtrlr.offset;
    final autoScroll =
        _autoScrollCalls > 0 || offsetDiff <= widget.autoScrollThreshold;

    _items = UnmodifiableListView([
      ..._items,
      ...items.reversed,
    ]);

    _addNewItemsToAnimList(items);

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

  void _addNewItemsToAnimList(List<ItemType> newItems) {
    for (var i = 0; i < newItems.length; i++) {
      _itemAnimations[newItems[i]] = ItemAnimation(AnimationType.newMessage);

      final insertInd = _isReverse ? 0 : (_items.length - newItems.length + i);
      _animListKey.currentState!.insertItem(insertInd);
    }
  }

  void _addPagetoAnimList(List<ItemType> pageItems) {
    for (var i = 0; i < pageItems.length; i++) {
      final insertInd = _isReverse ? (_items.length - pageItems.length + i) : 0;
      _animListKey.currentState!.insertItem(insertInd);
    }
  }

  void _onVisibilityChange(int minInd, int maxInd) {
    widget.onVisibilityChange?.call(minInd, maxInd);

    if (minInd <= widget.pageRequestThreshold) _requestPage();
  }

  void _handleScrollChange() {
    // debugPrint('InfiniteListView. _handleScrollChange offset: $offset');

    _autoScrollRegionUpdate(_scrollCtrlr.offset);
  }

  void _autoScrollRegionUpdate(double offset) {
    final newAutoScrollState = _scrollCtrlr.position.maxScrollExtent - offset <=
        widget.autoScrollThreshold;
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
    final diff = _scrollCtrlr.position.maxScrollExtent - _scrollCtrlr.offset;

    final duration = math
        .min(
          widget.maxAutoScrollDuration,
          math.max(0, diff * 2.5),
        )
        .toInt(); // ms

    await _scrollCtrlr.animateTo(
      _scrollCtrlr.position.maxScrollExtent,
      duration: Duration(milliseconds: duration),
      curve: Curves.linear,
    );

    _autoScrollCalls = math.max(0, _autoScrollCalls - 1);
  }

  bool _onUserScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.forward) {
      _autoScrollCalls = 0;
    }

    return false;
  }

  Widget _itemBuilder(BuildContext context, int index) {
    Widget itemWidget = VisibilityDetector(
      key: ObjectKey(_items[index]),
      onVisibilityChanged: (info) => _visibilityCtrlr.updateItemVisibility(
        info: info,
        index: index,
      ),
      child: widget.itemBuilder(context, index),
    );

    if (index < _items.length - 1) {
      itemWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          itemWidget,
          widget.separatorBuilder(context, index),
        ],
      );
    }

    return itemWidget;
  }

  Widget _animatedItemBuilder(
    BuildContext context,
    int index,
    Animation<double> anim,
  ) {
    final adjustedInd = _isReverse ? _items.length - index - 1 : index;

    return AnimatedItem(
      itemAnimation: _itemAnimations[_items[adjustedInd]],
      animation: anim,
      child: _itemBuilder(context, adjustedInd),
    );
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

    Widget listView = AnimatedList(
      padding: widget.padding.copyWith(top: listTopPadding),
      controller: _scrollCtrlr,
      reverse: _isReverse,
      shrinkWrap: true,
      itemBuilder: _animatedItemBuilder,
    );

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
