import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16.0, // Match text size
      width: 16.0, // Match text size
      child: CircularProgressIndicator(
        strokeWidth: 2.0, // Adjust thickness
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
  
}