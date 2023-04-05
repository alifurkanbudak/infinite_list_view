import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VisibilityController<ItemType> {
  final void Function(Set<ItemType> visibleItems) onVisibilityChange;
  final bool Function() isWidgetAlive;

  final _visibleItems = <ItemType>{};

  VisibilityController({
    required this.onVisibilityChange,
    required this.isWidgetAlive,
  });

  void updateItemVisibility({
    required VisibilityInfo info,
    required ItemType item,
  }) {
    final wasVisible = _visibleItems.contains(item);
    final isVisible = info.visibleFraction > 0;

    if (wasVisible && !isVisible) {
      _visibleItems.remove(item);
      debugPrint(
          'InfiniteListView. updateItemVisibility. _visibleItems: $_visibleItems');

      if (isWidgetAlive()) onVisibilityChange(Set.from(_visibleItems));
    }

    if (!wasVisible && isVisible) {
      _visibleItems.add(item);
      debugPrint(
          'InfiniteListView. updateItemVisibility. _visibleItems: $_visibleItems');

      if (isWidgetAlive()) onVisibilityChange(Set.from(_visibleItems));
    }
  }

  void updateItem({required ItemType oldItem, required ItemType newItemm}) {
    if (_visibleItems.remove(oldItem)) _visibleItems.add(newItemm);
  }
}
