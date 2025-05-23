import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  final bool light;

  const Loader({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16.0, // Match text size
      width: 16.0, // Match text size
      child: CircularProgressIndicator(
        strokeWidth: 2.0, // Adjust thickness
        color: light
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
  
}