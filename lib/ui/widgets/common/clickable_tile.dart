import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class ClickableTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const ClickableTile({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(spacing), 
        child: Row(
        children: [
          Expanded( child: child),
          Icon(Icons.chevron_right),
        ],
      )
    ));
  }
}