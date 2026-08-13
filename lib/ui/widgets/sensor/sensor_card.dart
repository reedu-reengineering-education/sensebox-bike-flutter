import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {
  final Widget child;
  final String title;
  final IconData icon;
  final Color color;

  const SensorCard({
    super.key,
    required this.child,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).canvasColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
