class VisibilityCallbacks {
  final bool Function(int index) shouldWatchVisiblity;
  final void Function(int minInd, int maxInd) onVisibilityChange;

  const VisibilityCallbacks({
    required this.shouldWatchVisiblity,
    required this.onVisibilityChange,
  });
}
