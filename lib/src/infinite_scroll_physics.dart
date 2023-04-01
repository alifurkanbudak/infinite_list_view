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
    final position = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    if (!onListSizeChanged()) return position;

    bool isFirstScrollableState =
        (oldPosition.extentBefore + oldPosition.extentAfter == 0) &&
            (newPosition.extentBefore + newPosition.extentAfter > 0);
    if (isFirstScrollableState) return newPosition.maxScrollExtent;

    final diff = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;

    return position + diff;
  }
}
