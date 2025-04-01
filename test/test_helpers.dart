import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes common test dependencies
void initializeTestDependencies() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock SharedPreferences
  const MethodChannel channel = 
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{}; 
      }
      return null;
    },
  );

  // Ensure SharedPreferences is initialized
  SharedPreferences.setMockInitialValues({});
}

/// Creates a MaterialApp wrapper with localization support 
Widget createLocalizedTestApp({
  required Widget child,
  required Locale locale,
  List<LocalizationsDelegate<dynamic>>? additionalDelegates,
}) {
  return MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      ...?additionalDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: child,
  );
}

/// Disables Provider debug checks
void disableProviderDebugChecks() {
  Provider.debugCheckInvalidValueType = null;
}
