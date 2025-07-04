import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

class ButtonWithLoader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String text;
  final double? width; // Make width optional

  const ButtonWithLoader({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
    this.width, // Optional
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      style: FilledButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(vertical: 12), // Vertical padding only
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
      final screenWidth = MediaQuery.of(context).size.width;
      return SizedBox(
        width: screenWidth * width!,
        child: button,
      );
    } else {
      return button;
    }
  }
}
