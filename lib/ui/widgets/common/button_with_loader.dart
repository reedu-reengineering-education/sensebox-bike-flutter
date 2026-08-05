import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

class ButtonWithLoader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String text;
  final double? width; // Make width optional
  final bool? inverted; // Use dark theme if true

  const ButtonWithLoader({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
    this.width, // Optional
    this.inverted = false, // Default to false (light theme)
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: inverted == true
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary,
        foregroundColor: inverted == true
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            Loader(),
            SizedBox(width: 8),
          ],
          Text(text),
        ],
      ),
    );

    if (width != null) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      // Phone: fraction of screen (unchanged). Tablet: also cap to content width.
      final base = context.isTablet
          ? min(screenWidth, context.contentMaxWidth)
          : screenWidth;
      return SizedBox(
        width: base * width!,
        child: button,
      );
    } else {
      return button;
    }
  }
}
