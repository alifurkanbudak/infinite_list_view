import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class InfiniteLoader extends StatefulWidget {
  const InfiniteLoader({
    required GlobalKey<InfiniteLoaderState> key,
    required this.isFetching,
    required this.spacing,
    required this.size,
    required this.androidColor,
    required this.androidStrokeWidth,
  }) : super(key: key);

  final bool isFetching;
  final double spacing;
  final double size;
  final double androidStrokeWidth;
  final Color? androidColor;

  @override
  State<InfiniteLoader> createState() => InfiniteLoaderState();
}

class InfiniteLoaderState extends State<InfiniteLoader> {
  final bool _showAndroid = Platform.isAndroid;

  double _offset = 0;

  void updateOffset(double offset) {
    setState(() => _offset = offset);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSize =
        widget.size - (_showAndroid ? widget.androidStrokeWidth : 0);

    return Positioned(
      top: widget.spacing - (_offset > 0 ? _offset : _offset / 2),
      height: effectiveSize,
      width: effectiveSize,
      child: AnimatedOpacity(
        opacity: widget.isFetching ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: _showAndroid
            ? CircularProgressIndicator(
                strokeWidth: widget.androidStrokeWidth,
                color: widget.androidColor,
              )
            : CupertinoActivityIndicator(
                radius: widget.size / 2,
              ),
      ),
    );
  }
}
