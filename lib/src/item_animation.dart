import 'package:flutter/material.dart';

enum AnimationType {
  newMessage,
  none,
}

class ItemAnimation {
  final AnimationType animationType;
  final Duration delay;

  ItemAnimation(
    this.animationType, [
    this.delay = Duration.zero,
  ]);
}

class AnimatedItem extends StatelessWidget {
  final ItemAnimation? itemAnimation;
  final Widget child;
  final Animation<double> animation;

  const AnimatedItem({
    super.key,
    required this.itemAnimation,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (itemAnimation == null) return child;

    return SizeTransition(
      sizeFactor: animation,
      child: child,
    );
  }
}
