import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';

class CircularListTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const CircularListTile({
    super.key,
    required this.title,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? theme.colorScheme.secondary
                    : Colors.transparent,
                border: Border.all(
                  color: theme.colorScheme.secondary,
                  width: borderWidth,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: iconSize,
                      color: theme.colorScheme.onSecondary,
                    )
                  : null,
            ),
            const SizedBox(width: spacing),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.secondary
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}