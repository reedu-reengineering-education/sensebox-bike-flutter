import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final EdgeInsetsGeometry outerPadding;

  const InfoBanner({
    super.key,
    required this.text,
    this.color = Colors.blue,
    this.outerPadding = const EdgeInsets.symmetric(
      vertical: 0,
      horizontal: spacing / 2,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: outerPadding,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(spacing),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: iconSize,
              color: color,
            ),
            const SizedBox(width: spacing / 2),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
