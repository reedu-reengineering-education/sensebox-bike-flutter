import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum DialogType { error, confirmation }

Future<bool?> showCustomDialog({
  required BuildContext context,
  required String message,
  DialogType type = DialogType.error, // Default to error dialog
}) async {
  final localizations = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        type == DialogType.error
            ? localizations.generalError
            : localizations.generalConfirmation,
        style: type == DialogType.error
            ? TextStyle(color: theme.colorScheme.error) // Red title for error
            : null, // Default styling for confirmation
      ),
      content: Text(message),
      actions: [
        if (type == DialogType.confirmation)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: Text(localizations.generalCancel),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true), // Proceed
          child: Text(localizations.generalOk),
        ),
      ],
    ),
  );
}