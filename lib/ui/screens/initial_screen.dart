import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/services/storage/privacy_policy_storage.dart';

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
    final acceptedAt =
        await context.read<PrivacyPolicyStorage>().loadAcceptedAt();

    if (!context.mounted) return;

    context.go(_getNextLocation(acceptedAt));
  }

  String _getNextLocation(String? acceptedAt) {
    if (!FeatureFlags.showPrivacyPolicyScreen) {
      return AppRoutes.home;
    }

    return acceptedAt != null ? AppRoutes.home : AppRoutes.privacyPolicy;
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
