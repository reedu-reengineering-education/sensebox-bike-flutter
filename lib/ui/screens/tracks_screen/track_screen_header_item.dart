import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

class TracksScreenHeaderItem extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? hours;
  final String? minutes;

  const TracksScreenHeaderItem({
    required this.icon,
    this.label,
    this.hours,
    this.minutes,
    super.key,
  });
  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: iconSizeLarge),
        if (hours == null && minutes == null) 
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label!.split(' ')[0], 
                style: theme.bodyLarge?.copyWith(
                  height: 1.0, // Remove extra line height
                ),
              ),
              const SizedBox(width: spacing / 4), 
              Text(
                label!.split(' ').sublist(1).join(' '), 
                style: theme.bodySmall
              ),
            ],
          )
        else
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              hours!.split(' ')[0],
              style: theme.bodyLarge?.copyWith(
                height: 1.0, // Remove extra line height
              ),
            ),
            const SizedBox(width: spacing / 4),
            Text(hours!.split(' ').sublist(1).join(' '), style: theme.bodySmall),
            const SizedBox(width: spacing / 4),
            Text(
              minutes!.split(' ')[0],
              style: theme.bodyLarge?.copyWith(
                height: 1.0, // Remove extra line height
              ),
            ),
            const SizedBox(width: spacing / 4),
            Text(minutes!.split(' ').sublist(1).join(' '),
                style: theme.bodySmall),
          ],
        ),
      ],
    );
  }
}