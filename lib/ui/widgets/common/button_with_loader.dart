import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

class ButtonWithLoader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String text;
  final double width;

  const ButtonWithLoader({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * width, // 40% of the screen width
      child: FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the content
          children: [
            if (isLoading) ...[
              Loader(),
              SizedBox(width: 8), // Add some spacing between the loader and text
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}
