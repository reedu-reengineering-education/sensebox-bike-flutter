import 'package:flutter/material.dart';
import 'package:sensebox_bike/theme.dart';

Widget settingsNavigationChevron(BuildContext context) {
  return Icon(
    Icons.chevron_right,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

TextStyle settingsValueSubtitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w500,
      );
}

Color settingsInfoColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

TextStyle settingsInfoSubtitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall!.copyWith(
        color: settingsInfoColor(context),
      );
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: spacing * 3,
        bottom: spacing,
        left: spacing,
        right: spacing,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class SettingsNavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailingPrefix;

  const SettingsNavigationTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingPrefix,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailingPrefix == null
          ? settingsNavigationChevron(context)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                trailingPrefix!,
                const SizedBox(width: 4),
                settingsNavigationChevron(context),
              ],
            ),
      onTap: onTap,
    );
  }
}

class SettingsValueTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const SettingsValueTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value, style: settingsValueSubtitleStyle(context)),
      onTap: onTap,
    );
  }
}

class SettingsInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onTap;

  const SettingsInfoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final infoColor = settingsInfoColor(context);

    return ListTile(
      leading: Icon(icon, color: infoColor),
      title: Text(title, style: TextStyle(color: infoColor)),
      subtitle: subtitle,
      trailing: onTap == null ? null : settingsNavigationChevron(context),
      onTap: onTap,
    );
  }
}
