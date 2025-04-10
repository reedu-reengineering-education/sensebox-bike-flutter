import 'package:flutter/material.dart';

class CustomSpacer extends StatelessWidget {
  final double height;

  const CustomSpacer({super.key, this.height = 16.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}
