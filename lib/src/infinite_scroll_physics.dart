import 'package:flutter/material.dart';

class InfiniteScrollPhysicsState {
  bool _keepNextScroll = false;
}

class InfiniteScrollPhysics extends ScrollPhysics {
  final InfiniteScrollPhysicsState state;

  const InfiniteScrollPhysics({
    super.parent,
    required this.state,
  });

  @override
  InfiniteScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return InfiniteScrollPhysics(
      parent: buildParent(ancestor),
      state: state,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final tempKeepNextScroll = state._keepNextScroll;
    state._keepNextScroll = false;

    debugPrint(
      'InfiniteListView. adjustPositionForNewDimensions. keepNextScroll: $tempKeepNextScroll, sizeChange: ${newPosition.maxScrollExtent - oldPosition.maxScrollExtent} $oldPosition ==> $newPosition',
    );

    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    // if (!tempKeepNextScroll) {
    //   debugPrint(
    //       'InfiniteListView. adjustPositionForNewDimensions. _keepNextScroll: false. position: $position');
    //   return position;
    // }

    // return position;
  }

  void keepNextScroll() {
    state._keepNextScroll = true;
  }
}
