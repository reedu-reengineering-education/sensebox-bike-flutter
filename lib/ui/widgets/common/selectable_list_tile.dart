import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class SelectableListTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableListTile({
    super.key,
    required this.title,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: padding, horizontal: padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colorScheme.secondary : Colors.transparent,
                border: Border.all(
                    color: colorScheme.secondary, width: borderWidth),
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      size: iconSize, color: colorScheme.onSecondary)
                  : null,
            ),
            const SizedBox(width: spacing),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.secondary
                    : textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}