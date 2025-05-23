import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Future<void> showErrorDialog(BuildContext context, String errorMessage) async {
  final localizations = AppLocalizations.of(context)!;
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localizations.generalError),
      content: Text(errorMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.generalOk),
        ),
      ],
    ),
  );
}