import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  static void reportToSentry(dynamic error, StackTrace stack) {
    logToConsole(error, stack);
    Sentry.captureException(error, stackTrace: stack);
  }

  static void handleError(dynamic error, StackTrace stack,
      {bool sendToSentry = true}) {
    logToConsole(error, stack);
    // This exception was already reported to Sentry
    // end exceptions generated during debugging are not reported
    if (sendToSentry) {
      Sentry.captureException(error, stackTrace: stack);
    }

    if (!kDebugMode) {
      if (error is LocationPermissionDenied ||
          error is LoginError ||
          error is RegistrationError ||
          error is ScanPermissionDenied ||
          error is NoSenseBoxSelected ||
          error is ExportDirectoryAccessError ||
          error is UploadFailureError) {
        showUserFeedback(error);
      } else {
        logToConsole(error, stack);
      }
    } else {
      showUserFeedback(error);
    }
  }

  static Color get errorColor => scaffoldKey.currentContext != null
      ? Theme.of(scaffoldKey.currentContext!).colorScheme.error
      : Colors.red;

  static void showUserFeedback(dynamic error) {
    final context = scaffoldKey.currentContext;

    if (context == null) return;

    scaffoldKey.currentState?.showSnackBar(SnackBar(
        content: Text(parseError(error, context)),
        backgroundColor: errorColor,
        showCloseIcon: true,
        duration: Duration(seconds: 10)));
  }

  static String parseError(dynamic error, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (error is LocationPermissionDenied) {
      return localizations?.errorNoLocationAccess ??
          'Location services are disabled or access is denied. Please enable location services and allow the app to access your location in the phone settings.';
    } else if (error is ScanPermissionDenied) {
      return localizations?.errorNoScanAccess ??
          'Please allow the app to scan nearby devices in the phone settings.';
    } else if (error is NoSenseBoxSelected) {
      return localizations?.errorNoSenseBoxSelected ??
          'Please log in to your openSenseMap account and select a box to upload sensor data to the cloud.';
    } else if (error is ExportDirectoryAccessError) {
      return localizations?.errorExportDirectoryAccess ??
          'Error accessing export directory. Please make sure the app has permission to access the storage.';
    } else if (error is UploadFailureError) {
      return localizations?.errorUploadFailed ??
          'Data upload failed. Please check your internet connection and try again.';
    } else if (error is LoginError) {
      return '${localizations?.errorLoginFailed} ${error.toString()}';
    } else if (error is RegistrationError) {
      return '${localizations?.errorRegistrationFailed} ${error.toString()}';
    }

    return 'An unknown error occurred.\n Details: ${error.toString()}';
  }

  static void logToConsole(dynamic error, StackTrace stack) {
    debugPrintStack(stackTrace: stack, label: error.toString());
  }
}
