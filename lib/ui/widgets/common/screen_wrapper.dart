import 'package:flutter/material.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget child;
  final String? title; 
  final double padding;

  const ScreenWrapper(
      {super.key, required this.child, this.title, this.padding = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? '')), 
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}