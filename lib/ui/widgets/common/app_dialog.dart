import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';

enum AppDialogType { info, error, success, confirmation, destructiveConfirmation }

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final AppDialogType type;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.type = AppDialogType.info,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, iconColor, titleColor) = _styleForType(type, theme);

    return AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(color: titleColor),
            ),
          ),
        ],
      ),
      content: content,
      actions: actions,
    );
  }

  static Widget messageContent(BuildContext context, String message) {
    return Text(
      message,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  static (IconData, Color, Color?) _styleForType(
    AppDialogType type,
    ThemeData theme,
  ) {
    switch (type) {
      case AppDialogType.info:
      case AppDialogType.confirmation:
        return (
          Icons.info_outline,
          theme.colorScheme.info,
          theme.colorScheme.primary,
        );
      case AppDialogType.error:
      case AppDialogType.destructiveConfirmation:
        return (
          Icons.error_outline,
          theme.colorScheme.error,
          theme.colorScheme.error,
        );
      case AppDialogType.success:
        return (
          Icons.check_circle_outline,
          theme.colorScheme.success,
          theme.colorScheme.primary,
        );
    }
  }
}

/// Shows a standardized app dialog matching the upload requirements UI.
///
/// Returns `true` when the primary action is pressed, `false` when cancelled,
/// and `null` if the dialog is dismissed without an action.
Future<bool?> showAppDialog({
  required BuildContext context,
  required String title,
  required String message,
  AppDialogType type = AppDialogType.info,
  bool barrierDismissible = false,
  String? cancelLabel,
  String? confirmLabel,
  bool confirmIsDestructive = false,
}) {
  final localizations = AppLocalizations.of(context)!;
  final resolvedConfirmLabel = confirmLabel ?? localizations.generalOk;

  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final actions = <Widget>[];

      if (cancelLabel != null) {
        actions.add(
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        );
      }

      if (confirmIsDestructive) {
        actions.add(
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Theme.of(dialogContext).colorScheme.error,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(resolvedConfirmLabel),
          ),
        );
      } else if (cancelLabel != null) {
        actions.add(
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(resolvedConfirmLabel),
          ),
        );
      } else {
        actions.add(
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(resolvedConfirmLabel),
          ),
        );
      }

      return AppDialog(
        type: type,
        title: title,
        content: AppDialog.messageContent(dialogContext, message),
        actions: actions,
      );
    },
  );
}

Future<bool?> showAppDialogWithContent({
  required BuildContext context,
  required String title,
  required Widget content,
  AppDialogType type = AppDialogType.info,
  bool barrierDismissible = false,
  String? cancelLabel,
  String? confirmLabel,
  bool confirmIsPrimary = true,
}) {
  final localizations = AppLocalizations.of(context)!;
  final resolvedConfirmLabel = confirmLabel ?? localizations.generalOk;

  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      final actions = <Widget>[];

      if (cancelLabel != null) {
        actions.add(
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        );
      }

      if (confirmIsPrimary && cancelLabel != null) {
        actions.add(
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(resolvedConfirmLabel),
          ),
        );
      } else {
        actions.add(
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(resolvedConfirmLabel),
          ),
        );
      }

      return AppDialog(
        type: type,
        title: title,
        content: content,
        actions: actions,
      );
    },
  );
}
