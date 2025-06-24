import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget? content;

  const ScreenWrapper({super.key, this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(spacing),
        child: content,
      ),
    );
  }
}