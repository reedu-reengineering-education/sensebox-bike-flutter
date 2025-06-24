import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget child;

  const ScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(spacing),
        child: child,
      ),
    );
  }
}