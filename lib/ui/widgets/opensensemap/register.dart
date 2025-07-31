import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/common/email_field.dart';
import 'package:sensebox_bike/ui/widgets/common/password_field.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool isLoading = false; // Track loading state
  bool isAccepted = false;
  String? privacyPolicyError;

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void validatePrivacyPolicy() {
    setState(() {
      privacyPolicyError = isAccepted
          ? null
          : AppLocalizations.of(context)!
              .openSenseMapRegisterAcceptTermsError; // Error message
    });
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
                enabled: !isLoading,
                decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.openSenseMapRegisterName),
              ),
              const CustomSpacer(),
              EmailField(
                controller: emailController,
                enabled: !isLoading,
              ),
              const CustomSpacer(),
              PasswordField(
                controller: passwordController,
                validator: passwordValidator,
                enabled: !isLoading,
              ),
              const CustomSpacer(),
              PasswordField(
                controller: confirmPasswordController,
                isConfirmationField: true,
                confirmationValidator: passwordConfirmationValidator,
                passwordController: passwordController,
                enabled: !isLoading,
              ),
              const CustomSpacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isAccepted = !isAccepted;
                  });
                  validatePrivacyPolicy();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center, // Center vertically
                      children: [
                        Checkbox(
                          value: isAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              isAccepted = value ?? false;
                            });
                            validatePrivacyPolicy();
                          },
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium,
                              children: [
                                TextSpan(
                                    text: AppLocalizations.of(context)!
                                        .openSenesMapRegisterAcceptTermsPrefix),
                                TextSpan(text: " "),
                                TextSpan(
                                  text: AppLocalizations.of(context)!
                                      .openSenseMapRegisterAcceptTermsPrivacy,
                                  style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      launchUrl(Uri.parse(privacyPolicyUrl));
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (privacyPolicyError != null)
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0), // Add padding to the error message
                        child: Text(
                          privacyPolicyError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const CustomSpacer(),
              ButtonWithLoader(
                  isLoading: isLoading,
                  text: AppLocalizations.of(context)!.generalRegister,
                  width: 0.7,
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () async {
                          // Validate the form and the privacy policy checkbox
                          final isFormValid =
                              formKey.currentState?.validate() == true;
                          bool isRegistrationSuccessful = false;

                          validatePrivacyPolicy(); // Validate the checkbox

                          if (isFormValid && isAccepted) {
                            setState(() {
                              isLoading = true; // Start loading
                            });

                            validatePrivacyPolicy();

                            try {
                              // Registration logic here
                              await widget.bloc.register(
                                  nameController.value.text,
                                  emailController.value.text,
                                  passwordController.value.text);

                              isRegistrationSuccessful = true;
                            } catch (e, stack) {
                              ErrorService.handleError(
                                  RegistrationError(e), stack);
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isLoading = false; // Stop loading
                                });
                              }
                            }

                            if (context.mounted &&
                                isRegistrationSuccessful &&
                                mounted) {
                              // Navigate to the home screen after successful login
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AppHome()),
                              );
                            }
                          }
                        }),
            ],
          ),
        ),
      ),
    );
  }
}
