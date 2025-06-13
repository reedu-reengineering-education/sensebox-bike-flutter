import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class Hint extends StatelessWidget {
  final String text;

  const Hint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: spacing/2, left: spacing),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.primaryFixedDim),
          const SizedBox(width: spacing),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.primaryFixedDim),
            ),
          ),
        ],
      ),
    );
  }
}