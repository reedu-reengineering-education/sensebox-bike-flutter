import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/common/email_field.dart';
import 'package:sensebox_bike/ui/widgets/common/error_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/password_field.dart';
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
  bool isLoading = false; // Track loading state

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
              const CustomSpacer(),
              EmailField(controller: emailController),
              const CustomSpacer(),
              PasswordField(
                controller: passwordController,
                validator: passwordValidator,
              ),
              const CustomSpacer(),
              PasswordField(
                controller: confirmPasswordController,
                isConfirmationField: true,
                confirmationValidator: passwordConfirmationValidator,
                passwordController: passwordController,
              ),
              
              const CustomSpacer(),
              ButtonWithLoader(
                  isLoading: isLoading,
                  text: AppLocalizations.of(context)!.openSenseMapRegister,
                  width: 0.7,
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () async {
                          if (formKey.currentState?.validate() == true) {
                            setState(() {
                              isLoading = true; // Start loading
                            });
                            try {
                              // Registration logic here
                              await widget.bloc.register(
                                  nameController.value.text,
                                  emailController.value.text,
                                  passwordController.value.text);

                              if (context.mounted) {
                                Navigator.pop(
                                    context); // Close after registration
                                showLoginOrSenseBoxSelection(
                                    context, widget.bloc);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      ErrorDialog(errorMessage: e.toString()));
                              }
                            } finally {
                              setState(() {
                                isLoading = false; // Stop loading
                              });
                            }
                          }
                        }
              ),
            ],
          ),
        ),
      ),
    );
  }
}
