class VisibilityConfig {
  final bool Function(int index) shouldWatchVisiblity;
  final void Function(int minInd, int maxInd) onVisibilityChange;
  final Duration visibiltyCheckInterval;

  const VisibilityConfig({
    required this.shouldWatchVisiblity,
    required this.onVisibilityChange,
    this.visibiltyCheckInterval = Duration.zero,
  });
}
