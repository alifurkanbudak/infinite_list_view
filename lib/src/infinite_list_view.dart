import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'infinite_loader.dart';
import 'infinite_scroll_physics.dart';

class InfiniteListView<PageKeyType, ItemType, ScrollStateInfoType>
    extends StatefulWidget {
  const InfiniteListView({
    required GlobalKey<
            InfiniteListViewState<PageKeyType, ItemType, ScrollStateInfoType>>
        key,
    required this.initialPageKey,
    required this.requestPage,
    required this.getScrollStateInfo,
    required this.shouldHoldScroll,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.autoScrollThreshold = 50,
    this.maxAutoScrollDuration = 200,
    this.pageRequestThreshold = 100,
    this.loaderSize = 20,
    this.androidLoaderStrokeWidth = 2,
    this.loaderSpacing = 4,
    this.androidLoaderColor,
    this.padding,
  }) : super(key: key);

  final PageKeyType initialPageKey;

  final FutureOr<void> Function(PageKeyType pageKey) requestPage;

  final ScrollStateInfoType? Function() getScrollStateInfo;

  final bool Function({
    required ScrollStateInfoType? oldScrollStateInfo,
    required ScrollStateInfoType? newScrollStateInfo,
  }) shouldHoldScroll;

  final Widget Function(
    BuildContext context,
    int index,
    ItemType item,
  ) itemBuilder;

  final Widget Function(
    BuildContext context,
    int index,
  ) separatorBuilder;

  final EdgeInsets? padding;

  /// In pixels
  final double autoScrollThreshold;

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
      InfiniteListViewState<PageKeyType, ItemType, ScrollStateInfoType>();
}

class InfiniteListViewState<PageKeyType, ItemType, ScrollStateInfoType>
    extends State<
        InfiniteListView<PageKeyType, ItemType, ScrollStateInfoType>> {
  late PageKeyType _pageKey = widget.initialPageKey;

  UnmodifiableListView<ItemType> get items => _items;
  UnmodifiableListView<ItemType> _items = UnmodifiableListView([]);

  bool _isFetching = false;
  bool _isLastPageFetched = false;
  int _autoScrollCalls = 0;
  ScrollStateInfoType? _scrollStateInfo;

  final _listViewKey = GlobalKey();
  final _loaderKey = GlobalKey<InfiniteLoaderState>();

  late final _scrollPhysics = InfiniteScrollPhysics(
    shouldHoldScroll: _shouldHoldScroll,
  );
  final _scrollCtrlr = ScrollController();

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
    debugPrint(
        'addPage. items.length: ${pageItems.length}, pageKey: $pageKey, isLastPage: $isLastPage');

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

  void onError(Object error) {
    setState(() {
      _isFetching = false;
    });
  }

  bool _shouldHoldScroll() {
    final newState = widget.getScrollStateInfo();

    final tempOldState = _scrollStateInfo;
    _scrollStateInfo = newState;

    debugPrint('_shouldHoldScroll. $tempOldState => $newState');

    return widget.shouldHoldScroll(
      oldScrollStateInfo: tempOldState,
      newScrollStateInfo: newState,
    );
  }

  void _handleScrollChange() {
    final offset = _scrollCtrlr.offset;

    _loaderKey.currentState!.updateOffset(offset);

    bool requestPage = offset <= widget.pageRequestThreshold;
    if (requestPage) _requestPage();
  }

  void _requestPage() {
    if (_isFetching || _isLastPageFetched) return;
    setState(() => _isFetching = true);

    debugPrint('_fetchPage. pageKey: $_pageKey');

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

    return true;
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
        itemBuilder: (context, index) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.itemBuilder(context, index, _items[index]),
            if (index < _items.length) widget.separatorBuilder(context, index)
          ],
        ),
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
