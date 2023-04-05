import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VisibilityController {
  final void Function(int minInd, int maxInd) onVisibilityChange;
  final bool Function() isWidgetAlive;

  final _visibleInds = <int>{};
  int _indexOffset = 0;

  VisibilityController({
    required this.onVisibilityChange,
    required this.isWidgetAlive,
  });

  void updateItemVisibility({
    required VisibilityInfo info,
    required int index,
  }) {
    int effectiveInd = index - _indexOffset;

    final wasVisible = _visibleInds.contains(effectiveInd);
    final isVisible = info.visibleFraction > 0;

    if (wasVisible && !isVisible) {
      _visibleInds.remove(effectiveInd);
      _notify();
    }

    if (!wasVisible && isVisible) {
      _visibleInds.add(effectiveInd);
      _notify();
    }
  }

  // Will offset each visibile index before reporting
  void pageAdded(int pageSize) => _indexOffset += pageSize;

  void _notify() {
    num minInd = double.infinity;
    num maxInd = double.negativeInfinity;
    for (var i in _visibleInds) {
      if (i < minInd) minInd = i;
      if (i > maxInd) maxInd = i;
    }
    minInd += _indexOffset;
    maxInd += _indexOffset;

    if (isWidgetAlive()) onVisibilityChange(minInd.toInt(), maxInd.toInt());

    debugPrint(
      'InfiniteListView. updateItemVisibility. _visibleInds: $_visibleInds',
    );
  }
}
