import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/utils/common.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;

  const EmailField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
