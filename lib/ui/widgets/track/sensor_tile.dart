import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class SensorTile extends StatelessWidget {
  final String title;
  final Color cardColor;
  final Color sensorColor;
  final bool isSelected;
  final IconData sensorIcon;
  final void Function() onTap;

  const SensorTile({
    super.key,
    required this.title,
    required this.cardColor,
    required this.sensorColor,
    required this.isSelected,
    required this.sensorIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconAndTextColor = isSelected ? sensorColor : colorScheme.onSurface;

    return Card.filled(
      clipBehavior: Clip.hardEdge,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    Icon(sensorIcon, size: 24, color: iconAndTextColor),
                    const SizedBox(height: spacing),
                    if (title.split(' ').length == 2)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: title.split(' ').map((word) {
                          return Text(
                            word,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: iconAndTextColor,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: iconAndTextColor,
                        ),
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
