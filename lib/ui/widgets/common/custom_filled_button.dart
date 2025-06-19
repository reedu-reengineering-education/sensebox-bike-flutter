import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class CustomFilledButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const CustomFilledButton({
    required this.label,
    this.icon,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilledButton.icon(
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, color: theme.colorScheme.primary)
          : const SizedBox.shrink(),
      label: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.primary,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.tertiary.withOpacity(0.6),
        side: BorderSide(
          color: theme.colorScheme.tertiary,
          width: borderWidthRegular,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: theme.buttonBorderRadius, 
        ),
      ),
    );
  }
}