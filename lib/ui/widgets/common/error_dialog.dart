import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<bool?> showErrorDialog(BuildContext context, String message) async {
  final localizations = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.generalError),
      content: Text(message),
      actions: [
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