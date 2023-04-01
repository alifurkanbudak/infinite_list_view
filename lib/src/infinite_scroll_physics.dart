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
    debugPrint('oldPosition: $oldPosition, newPosition: $newPosition');

    final position = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    if (!onListSizeChanged()) {
      debugPrint('===== Change doesn\'t push the view. No need for adjusting');
      return position;
    }

    bool isFirstScrollableState =
        (oldPosition.extentBefore + oldPosition.extentAfter == 0) &&
            (newPosition.extentBefore + newPosition.extentAfter > 0);
    if (isFirstScrollableState) {
      debugPrint('===== First Scrollable State. jumping to the end');
      return newPosition.maxScrollExtent;
    }

    final diff = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;

    if (diff > 0) {
      debugPrint('===== Holding scroll view');
      // debugPrint('diff: $diff');

      return position + diff;
    } else {
      return position;
    }
  }
}
