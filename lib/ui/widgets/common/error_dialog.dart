import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ErrorDialog extends StatelessWidget {
  final String errorMessage;

  const ErrorDialog({Key? key, required this.errorMessage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.openSenseMapRegisterFailed,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog
          },
          child: Text(AppLocalizations.of(context)!.generalOk),
        ),
      ],
    );
  }
}
