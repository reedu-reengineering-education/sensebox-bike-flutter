import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String? emailValidator(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context)!.openSenseMapEmailErrorEmpty;
  }
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
    return AppLocalizations.of(context)!.openSenseMapEmailErrorInvalid;
  }
  return null;
}

String? passwordValidatorSimple(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty;
  }
  return null;
}

String? passwordValidator(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context)!.openSenseMapPasswordErrorEmpty;
  }
  if (value.length < 8) {
    return AppLocalizations.of(context)!
        .openSenseMapRegisterPasswordErrorCharacters;
  }
  return null;
}

String? passwordConfirmationValidator(
    BuildContext context, String? value, String? password) {
  if (value == null || value.isEmpty) {
    return AppLocalizations.of(context)!
        .openSenseMapRegisterPasswordConfirmErrorEmpty;
  }

  if (value != password) {
    return AppLocalizations.of(context)!
        .openSenseMapRegisterPasswordErrorMismatch;
  }
  return null;
}

// Helper method to truncate the box name to 15 characters
String truncateBoxName(String name) {
  return name.length > 15 ? '${name.substring(0, 12)}...' : name;
}
