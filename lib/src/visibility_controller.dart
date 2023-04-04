import 'package:visibility_detector/visibility_detector.dart';

class VisibilityController<ItemType> {
  final void Function(Set<ItemType> visibleItems) onVisibilityChange;

  final _visibleItems = <ItemType>{};

  VisibilityController(this.onVisibilityChange);

  void updateItemVisibility({
    required VisibilityInfo info,
    required ItemType item,
  }) {
    final wasVisible = _visibleItems.contains(item);
    final isVisible = info.visibleFraction > 0;

    if (wasVisible && !isVisible) {
      _visibleItems.remove(item);
      onVisibilityChange(Set.from(_visibleItems));
    }

    if (!wasVisible && isVisible) {
      _visibleItems.add(item);
      onVisibilityChange(Set.from(_visibleItems));
    }
  }

  void updateItem({required ItemType oldItem, required ItemType newItemm}) {
    if (_visibleItems.remove(oldItem)) _visibleItems.add(newItemm);
  }
}
