import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Theme.of(context).colorScheme.secondary
                  : Colors.transparent,
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 10,
                    color: Theme.of(context).colorScheme.onSecondary,
                  )
                : null,
          ),
          const SizedBox(width: 12), // Space between the circle and the text
          Text(title),
        ],
      ),
    );
  }
}