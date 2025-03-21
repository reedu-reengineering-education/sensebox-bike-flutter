import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.openSenseMapPassword,
                ),
                obscureText: true,
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
                return FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() == true) {
                      try {
                        await widget.bloc.login(
                          emailController.text,
                          passwordController.text,
                        );
                        Navigator.pop(context); // Close after login
                        showLoginOrSenseBoxSelection(context, widget.bloc);
                      } catch (e) {
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error,
                                          color: Colors.red),
                                      const SizedBox(height: 8),
                                      Text(
                                          AppLocalizations.of(context)!
                                              .openSenseMapLoginFailed,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium),
                                      const SizedBox(height: 16),
                                      Text(e.toString(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium),
                                    ],
                                  ),
                                ));
                      }
                    }
                  },
                  child: Text(
                      AppLocalizations.of(context)!.openSenseMapLoginShort),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
