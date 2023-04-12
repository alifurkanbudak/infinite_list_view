import 'package:flutter/material.dart';

class InfiniteScrollPhysics extends ScrollPhysics {
  /// Should return whether to maintain the view
  final bool Function() shouldKeepScroll;

  const InfiniteScrollPhysics({
    super.parent,
    required this.shouldKeepScroll,
  });

  @override
  InfiniteScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return InfiniteScrollPhysics(
      parent: buildParent(ancestor),
      shouldKeepScroll: shouldKeepScroll,
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

    if (!shouldKeepScroll()) {
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

    return position;
  }
}
