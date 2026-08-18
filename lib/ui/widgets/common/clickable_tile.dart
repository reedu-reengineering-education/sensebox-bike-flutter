import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class ClickableTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Widget? trailing;

  const ClickableTile({
    super.key,
    required this.child,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
                padding: const EdgeInsets.only(left: spacing * 1.5),
                child: Row(
                  children: [
                    Expanded(child: child),
                    trailing ?? Icon(Icons.chevron_right),
                  ],
                ))));
  }
}
