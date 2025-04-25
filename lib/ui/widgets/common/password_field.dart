import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(BuildContext, String?)? validator; // Validator function
  final bool isConfirmationField; // Flag for confirmation field
  final String? Function(BuildContext, String?, String?)?
    confirmationValidator; 
  final TextEditingController? passwordController; 
  final bool enabled; // Flag to enable/disable the field

  const PasswordField({
    super.key,
    required this.controller,
    this.validator,
    this.isConfirmationField = false, // Default: not a confirmation field
    this.confirmationValidator, // Optional: validator for confirmation field
    this.passwordController, // Optional: original password for comparison
      this.enabled = true
  });

  @override
  _PasswordFieldState createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      enabled: widget.enabled,
      autofillHints: const [AutofillHints.password],
      controller: widget.controller,
      obscureText: !_isPasswordVisible, // Toggle visibility
      decoration: InputDecoration(
        labelText: widget.isConfirmationField
            ? AppLocalizations.of(context)!.openSenseMapRegisterPasswordConfirm
            : AppLocalizations.of(context)!.openSenseMapPassword,
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible; // Toggle visibility state
            });
          },
        ),
      ),
      validator: (value) {
        if (widget.isConfirmationField) {
          // Use the custom confirmation validator if provided
          if (widget.confirmationValidator != null) {
            return widget.confirmationValidator!(
                context, value, widget.passwordController?.text);
          }
        } else if (widget.validator != null) {
          // Use the custom validator for regular password field
          return widget.validator!(context, value);
        }
        return null;
      },
    );
  }
}
