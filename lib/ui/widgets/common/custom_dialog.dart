import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

enum DialogType { error, confirmation }

Future<bool?> showCustomDialog({
  required BuildContext context,
  required String message,
  DialogType type = DialogType.error, // Default to error dialog
}) async {
  final localizations = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showAppDialog<bool>(
    context: context,
    builder: (context) => AppAlertDialog(
      title: Text(
        type == DialogType.error
            ? localizations.generalError
            : localizations.generalConfirmation,
        style: type == DialogType.error
            ? TextStyle(color: theme.colorScheme.error)
            : null,
      ),
      content: Text(message),
      actions: [
        if (type == DialogType.confirmation)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.generalCancel),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(localizations.generalOk),
        ),
      ],
    ),
  );
}
