import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class RegisterForm extends StatefulWidget {
  final OpenSenseMapBloc bloc;
  const RegisterForm({super.key, required this.bloc});

  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
                autofillHints: const [AutofillHints.name],
                controller: nameController,
                decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.openSenseMapRegisterName),
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofillHints: const [AutofillHints.email],
                controller: emailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.openSenseMapEmail,
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
                  if (value.length < 8) {
                    return AppLocalizations.of(context)!
                        .openSenseMapRegisterPasswordErrorCharacters;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                autofillHints: const [AutofillHints.password],
                controller: confirmPasswordController,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!
                        .openSenseMapRegisterPasswordConfirm),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!
                        .openSenseMapRegisterPasswordConfirmErrorEmpty;
                  }
                  if (value != passwordController.text) {
                    return AppLocalizations.of(context)!
                        .openSenseMapRegisterPasswordErrorMismatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() == true) {
                    try {
                      // Registration logic here
                      await widget.bloc.register(
                          nameController.value.text,
                          emailController.value.text,
                          passwordController.value.text);

                      Navigator.pop(context); // Close after registration
                      showLoginOrSenseBoxSelection(context, widget.bloc);
                    } catch (e) {
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error, color: Colors.red),
                                    const SizedBox(height: 8),
                                    Text(
                                        AppLocalizations.of(context)!
                                            .openSenseMapRegisterFailed,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
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
                child: Text(AppLocalizations.of(context)!.openSenseMapRegister),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
