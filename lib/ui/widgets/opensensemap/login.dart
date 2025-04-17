import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/common/email_field.dart';
import 'package:sensebox_bike/ui/widgets/common/error_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/password_field.dart';
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
  final GlobalKey<FormState> formKey =
      GlobalKey<FormState>(); // Track password visibility
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
              EmailField(
                controller: emailController,
                enabled: !isLoading,
              ),
              const CustomSpacer(),
              PasswordField(
                controller: passwordController,
                enabled: !isLoading,
                validator: (context, value) =>
                    passwordValidatorSimple(context, value),
              ),
              const CustomSpacer(),
              ButtonWithLoader(
                  isLoading: isLoading,
                text: AppLocalizations.of(context)!.generalLogin,
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
                              emailController.value.text,
                              passwordController.value.text,
                              );

                            if (context.mounted) {
                              // Navigate to the home screen after successful login
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AppHome()),
                              );
                            }
                            } catch (e) {
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    ErrorDialog(errorMessage: e.toString()),
                              );
                            }
                            } finally {
                              setState(() {
                                isLoading = false; // Stop loading
                              });
                            }
                          }
                        },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
