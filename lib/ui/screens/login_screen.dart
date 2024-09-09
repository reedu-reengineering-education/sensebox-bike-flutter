import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/screens/sensebox_selection_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context);

    // redirect to SenseBoxSelectionScreen if already logged in
    if (openSenseMapBloc.isAuthenticated) {
      return SenseBoxSelectionScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await openSenseMapBloc.login(
                    emailController.text,
                    passwordController.text,
                  );
                  MaterialPageRoute(
                      builder: (context) => SenseBoxSelectionScreen());
                } catch (e) {
                  print(e);
                }
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

// hello@felixerdmann.com
// pmZZFK4YZyTu7%
