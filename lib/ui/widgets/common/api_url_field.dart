import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class ApiUrlField extends StatefulWidget {
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
  State<ApiUrlField> createState() => _ApiUrlFieldState();
}

class _ApiUrlFieldState extends State<ApiUrlField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasStoredValue = widget.controller.text.isNotEmpty;
    final shouldShowHint = !_isFocused && !hasStoredValue;
    
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText ??
                  AppLocalizations.of(context)!.settingsApiUrl,
              hintText: shouldShowHint
                  ? (widget.defaultValue ?? 'https://api.opensensemap.org')
                  : null,
            ),
            validator: widget.validator ??
                (value) => _defaultValidator(context, value),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          if (widget.helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.helperText!,
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
