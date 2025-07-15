import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/utils/common.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const EmailField({super.key, required this.controller, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: enabled,
      autofillHints: const [AutofillHints.email],
      controller: controller,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.openSenseMapEmail,
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) => emailValidator(context, value),
    );
  }
}
