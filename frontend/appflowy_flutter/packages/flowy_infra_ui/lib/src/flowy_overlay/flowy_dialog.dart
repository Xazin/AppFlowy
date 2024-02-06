import 'dart:math';

import 'package:flutter/material.dart';

const _overlayContainerPadding = EdgeInsets.symmetric(vertical: 12);
const overlayContainerMaxWidth = 760.0;
const overlayContainerMinWidth = 320.0;
const _defaultInsetPadding =
    EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0);

class FlowyDialog extends StatelessWidget {
  const FlowyDialog({
    super.key,
    required this.child,
    this.title,
    this.shape,
    this.constraints,
    this.padding = _overlayContainerPadding,
    this.backgroundColor,
    this.expandHeight = true,
    this.alignment,
    this.insetPadding,
  });

  final Widget? title;
  final ShapeBorder? shape;
  final Widget child;
  final BoxConstraints? constraints;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final bool expandHeight;

  // Position of the Dialog
  final Alignment? alignment;

  // Inset of the Dialog
  final EdgeInsets? insetPadding;

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.of(context).size;
    final size = windowSize * 0.7;
    return SimpleDialog(
      alignment: alignment,
      insetPadding: insetPadding ?? _defaultInsetPadding,
      contentPadding: EdgeInsets.zero,
      backgroundColor: backgroundColor ?? Theme.of(context).cardColor,
      title: title,
      shape: shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      children: [
        Material(
          type: MaterialType.transparency,
          child: Container(
            height: expandHeight ? size.height : null,
            width: max(min(size.width, overlayContainerMaxWidth),
                overlayContainerMinWidth),
            constraints: constraints,
            child: child,
          ),
        )
      ],
    );
  }
}
