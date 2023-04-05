import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:infinite_list_view/src/visibility_controller.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'infinite_loader.dart';
import 'infinite_scroll_physics.dart';

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
    this.androidLoaderColor,
    this.padding,
    this.shouldWatchVisiblity,
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

  final bool Function(int index)? shouldWatchVisiblity;

  final void Function(Set<ItemType> visibleItems)? onVisibilityChange;

  final EdgeInsets? padding;

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
  late final _visibilityCtrlr = VisibilityController<ItemType>(
    onVisibilityChange: widget.onVisibilityChange ?? (_) {},
    isWidgetAlive: () => mounted,
  );

  late PageKeyType _pageKey = widget.initialPageKey;

  UnmodifiableListView<ItemType> get items => _items;
  UnmodifiableListView<ItemType> _items = UnmodifiableListView([]);

  bool _isFetching = false;
  bool _isLastPageFetched = false;
  int _autoScrollCalls = 0;

  // Used for comparing whether top item changed
  bool _isPageAdded = false;

  final _listViewKey = GlobalKey();
  final _loaderKey = GlobalKey<InfiniteLoaderState>();

  late final _scrollPhysics = InfiniteScrollPhysics(
    onListSizeChanged: _onListSizeChanged,
  );
  final _scrollCtrlr = ScrollController();

  bool _inAutoScrollRegion = true;

  @override
  void initState() {
    super.initState();

    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 100);
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
    if (pageItems.isNotEmpty) _isPageAdded = true;

    setState(() {
      _isLastPageFetched = isLastPage;
      _isFetching = false;
      _items = UnmodifiableListView([
        ...pageItems.reversed,
        ..._items,
      ]);
    });

    _pageKey = pageKey;

    HapticFeedback.mediumImpact();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScrollCalls > 0) _autoScrollToBottom();
      _handleScrollChange();
    });
  }

  /// Returns true if the list auto scrolled to view new messages
  bool addNewItems({required List<ItemType> items}) {
    final offsetDiff =
        _scrollCtrlr.position.maxScrollExtent - _scrollCtrlr.offset;
    final autoScroll =
        _autoScrollCalls > 0 || offsetDiff <= widget.autoScrollThreshold;

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
    _visibilityCtrlr.updateItem(
      oldItem: _items[index],
      newItemm: item,
    );

    setState(() {
      _items = UnmodifiableListView([
        ..._items.sublist(0, index),
        item,
        ..._items.sublist(index + 1),
      ]);
    });
  }

  void onError(Object error) {
    setState(() {
      _isFetching = false;
    });
  }

  void scrollToBottom() {
    _autoScrollToBottom();
  }

  bool _onListSizeChanged() {
    final maintainScroll = _isPageAdded;
    _isPageAdded = false;

    return maintainScroll;
  }

  void _handleScrollChange() {
    final offset = _scrollCtrlr.offset;

    _loaderKey.currentState!.updateOffset(offset);

    // Page request check
    bool requestPage = offset <= widget.pageRequestThreshold;
    if (requestPage) _requestPage();

    // Auto scroll state check
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
    Widget itemWidget = widget.itemBuilder(context, index);

    if (widget.shouldWatchVisiblity?.call(index) == true) {
      itemWidget = VisibilityDetector(
        key: ObjectKey(_items[index]),
        onVisibilityChanged: (info) => _visibilityCtrlr.updateItemVisibility(
          info: info,
          item: _items[index],
        ),
        child: itemWidget,
      );
    }

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

  @override
  Widget build(BuildContext context) {
    // Give space for the page loader widget
    final listTopPadding = _isLastPageFetched
        ? widget.padding?.top ?? 0
        : math.max(
            widget.loaderSize + widget.loaderSpacing * 2,
            widget.padding?.top ?? 0,
          );

    Widget listView = KeyedSubtree(
      key: _listViewKey,
      child: ListView.builder(
        shrinkWrap: true,
        controller: _scrollCtrlr,
        physics: _scrollPhysics,
        itemCount: _items.length,
        padding: EdgeInsets.fromLTRB(
          widget.padding?.left ?? 0,
          listTopPadding,
          widget.padding?.right ?? 0,
          widget.padding?.bottom ?? 0,
        ),
        itemBuilder: _itemBuilder,
      ),
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
