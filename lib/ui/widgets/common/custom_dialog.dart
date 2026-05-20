import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

enum DialogType { error, confirmation }

Future<bool?> showCustomDialog({
  required BuildContext context,
  required String message,
  DialogType type = DialogType.error,
}) {
  final localizations = AppLocalizations.of(context)!;

  return showAppDialog(
    context: context,
    title: type == DialogType.error
        ? localizations.generalError
        : localizations.generalConfirmation,
    message: message,
    type: type == DialogType.error
        ? AppDialogType.error
        : AppDialogType.confirmation,
    barrierDismissible: true,
    cancelLabel:
        type == DialogType.confirmation ? localizations.generalCancel : null,
  );
}
