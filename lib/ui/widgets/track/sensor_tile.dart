import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class SensorTile extends StatelessWidget {
  final String title;
  final Color cardColor;
  final Color sensorColor;
  final IconData sensorIcon;
  final void Function() onTap;

  const SensorTile({
    super.key,
    required this.title,
    required this.cardColor,
    required this.sensorColor,
    required this.sensorIcon,
    required this.onTap,
  });

  @override
Widget build(BuildContext context) {
  return Card.filled(
    clipBehavior: Clip.hardEdge,
    color: cardColor,
    child: InkWell(
      onTap: () => onTap(),
      child: Padding(
        padding: const EdgeInsets.all(spacing / 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(sensorIcon, size: 24, color: sensorColor),
                  const SizedBox(height: spacing),
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: sensorColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
}