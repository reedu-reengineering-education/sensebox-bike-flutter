import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget child;
  final String? title; 

  const ScreenWrapper({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? '')), 
      body: Padding(
        padding: const EdgeInsets.all(spacing),
        child: child,
      ),
    );
  }
}