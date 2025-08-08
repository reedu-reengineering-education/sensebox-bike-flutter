import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/common/email_field.dart';
import 'package:sensebox_bike/ui/widgets/common/password_field.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

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
      GlobalKey<FormState>();

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
          bottom:
              MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.bloc.isAuthenticatingNotifier,
                    builder: (context, isAuthenticating, child) {
                      return Column(
                        children: [
                          EmailField(
                            controller: emailController,
                            enabled: !isAuthenticating,
                          ),
                          const CustomSpacer(),
                          PasswordField(
                            controller: passwordController,
                            enabled: !isAuthenticating,
                            validator: (context, value) =>
                                passwordValidatorSimple(context, value),
                          ),
                          const CustomSpacer(),
                          ButtonWithLoader(
                            isLoading: isAuthenticating,
                            text: AppLocalizations.of(context)!.generalLogin,
                            width: 0.4,
                            onPressed: isAuthenticating
                                ? null
                                : () async {
                                    bool isLoginSuccessful = false;
                                    if (formKey.currentState?.validate() ==
                                        true) {
                                      try {
                                        await widget.bloc.login(
                                          emailController.value.text,
                                          passwordController.value.text,
                                        );
                                        isLoginSuccessful = true;
                                      } catch (e, stack) {
                                        ErrorService.handleError(
                                            LoginError(e), stack,
                                            sendToSentry: false);
                                      }

                                      if (isLoginSuccessful &&
                                          context.mounted) {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const AppHome(),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
