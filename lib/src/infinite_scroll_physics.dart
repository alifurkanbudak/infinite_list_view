import 'package:flutter/material.dart';

class InfiniteScrollPhysics extends ScrollPhysics {
  /// Should return whether to maintain the view
  final bool Function() onListSizeChanged;

  const InfiniteScrollPhysics({
    super.parent,
    required this.onListSizeChanged,
  });

  @override
  InfiniteScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return InfiniteScrollPhysics(
      parent: buildParent(ancestor),
      onListSizeChanged: onListSizeChanged,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    debugPrint(
      'InfiniteListView. adjustPositionForNewDimensions. $oldPosition ==> $newPosition',
    );

    final position = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    if (!onListSizeChanged()) {
      debugPrint(
          'InfiniteListView. adjustPositionForNewDimensions. no need to maintain scrol. position: $position');
      return position;
    }

    bool isFirstScrollableState =
        (oldPosition.extentBefore + oldPosition.extentAfter == 0) &&
            (newPosition.extentBefore + newPosition.extentAfter > 0);
    if (isFirstScrollableState) {
      debugPrint(
          'InfiniteListView. adjustPositionForNewDimensions. isFirstScrollableState');
      return newPosition.maxScrollExtent;
    }

    final diff = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
    debugPrint(
        'InfiniteListView. adjustPositionForNewDimensions. diff: $diff. position: $position. pos+diff: ${position + diff}');

    return position + diff;
  }
}
