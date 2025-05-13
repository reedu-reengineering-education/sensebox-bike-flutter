import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; 

class ErrorService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  static void handleError(dynamic error, StackTrace stack) {
    if (kDebugMode) {
      logToConsole(error, stack);
      showUserFeedback(error);
    } else {
      if (error is LocationPermissionDenied ||
          error is LoginError ||
          error is RegistrationError ||
          error is ScanPermissionDenied ||
          error is NoSenseBoxSelected) {
        showUserFeedback(error);
      } else {
        logToConsole(error, stack);
      }
    }
  }

  static Color get errorColor => scaffoldKey.currentContext != null
      ? Theme.of(scaffoldKey.currentContext!).colorScheme.error
        : Colors.red;

  static void showUserFeedback(dynamic error) {
    final context = scaffoldKey.currentContext;

    if (context == null) return;

    scaffoldKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(parseError(error, context)),
        backgroundColor: errorColor,
        showCloseIcon: true,
        duration: Duration(seconds: 10)
      )
    );
  }

  static String parseError(dynamic error, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (error is LocationPermissionDenied) {
      return localizations?.errorNoLocationAccess ??
          'Please allow the app to access your location in the phone settings.';
    } else if (error is ScanPermissionDenied) {
      return localizations?.errorNoScanAccess ??
          'Please allow the app to scan nearby devices in the phone settings.';
    } else if (error is NoSenseBoxSelected) {
      return localizations?.errorNoSenseBoxSelected ??
          'Please log in to your openSenseMap account and select a box to upload sensor data to the cloud.';
    }

    return 'Unknown error: ${error.toString()}';
  }

  static void logToConsole(dynamic error, StackTrace stack) {
    debugPrintStack(stackTrace: stack, label: error.toString());
  }
}
