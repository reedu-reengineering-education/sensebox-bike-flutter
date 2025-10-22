import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class ApiUrlField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? labelText;
  final String? helperText;
  final String? defaultValue;

  const ApiUrlField({
    super.key,
    required this.controller,
    this.validator,
    this.labelText,
    this.helperText,
    this.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText ?? AppLocalizations.of(context)!.settingsApiUrl,
              hintText: defaultValue ?? 'https://api.opensensemap.org',
            ),
            validator: validator ?? (value) => _defaultValidator(context, value),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          if (helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _defaultValidator(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)!.settingsApiUrlError;
    }
    
    // Basic URL validation
    final uri = Uri.tryParse(value);
    if (uri == null || (!uri.hasScheme || (!uri.scheme.startsWith('http')))) {
      return AppLocalizations.of(context)!.settingsApiUrlError;
    }
    
    return null;
  }
}
