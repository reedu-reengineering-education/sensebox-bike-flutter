import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/error_dialog.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginForm extends StatefulWidget {
  final OpenSenseMapBloc bloc;
  const LoginForm({super.key, required this.bloc});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false; // Track password visibility
  bool isLoading = false; // Track loading state

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Adjust for keyboard
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                autofillHints: const [AutofillHints.email],
                controller: emailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.openSenseMapEmail,
                  // No border
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!
                        .openSenseMapEmailErrorEmpty;
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return AppLocalizations.of(context)!
                        .openSenseMapEmailErrorInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofillHints: const [AutofillHints.password],
                controller: passwordController,
                obscureText: !_isPasswordVisible, // Toggle visibility
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.openSenseMapPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off, // Change icon based on state
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible =
                            !_isPasswordVisible; // Toggle state
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!
                        .openSenseMapPasswordErrorEmpty;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Builder(builder: (BuildContext context) {
                return ButtonWithLoader(
                  isLoading: isLoading,
                  text: AppLocalizations.of(context)!.openSenseMapLoginShort,
                  width: 0.4,
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () async {
                          if (formKey.currentState?.validate() == true) {
                            setState(() {
                              isLoading = true; // Start loading
                            });
                            try {
                              await widget.bloc.login(
                                emailController.text,
                                passwordController.text,
                              );
                              Navigator.pop(context); // Close after login
                              showLoginOrSenseBoxSelection(
                                  context, widget.bloc);
                            } catch (e) {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    ErrorDialog(errorMessage: e.toString()),
                              );
                            } finally {
                              setState(() {
                                isLoading = false; // Stop loading
                              });
                            }
                          }
                        },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
