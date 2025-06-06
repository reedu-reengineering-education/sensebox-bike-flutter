import 'package:flutter/material.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sensebox_bike/ui/screens/privacy_policy_screen.dart';

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
    final acceptedAt = prefs.getString(SharedPreferencesKeys.privacyPolicyAcceptedAt);

    if (!context.mounted) return;

    if (acceptedAt != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppHome()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
      );
    }
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