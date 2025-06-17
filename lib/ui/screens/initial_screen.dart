import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/screens/privacy_policy_screen.dart';
import 'package:sensebox_bike/feature_flags.dart';

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkPrivacyPolicyAcceptance();
  }

Future<void> _checkPrivacyPolicyAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedAt =
        prefs.getString(SharedPreferencesKeys.privacyPolicyAcceptedAt);

    if (!context.mounted) return;

    final Widget nextScreen = _getNextScreen(acceptedAt);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
}

Widget _getNextScreen(String? acceptedAt) {
    if (!FeatureFlags.showPrivacyPolicyScreen) {
      return const AppHome();
    }

    return acceptedAt != null ? const AppHome() : const PrivacyPolicyScreen();
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}