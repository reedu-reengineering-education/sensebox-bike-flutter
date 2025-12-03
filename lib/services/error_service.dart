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
          error is UploadFailureError ||
          error is DirectUploadFailureError ||
          error is PermanentAuthenticationError ||
          error is TrackHasNoGeolocationsException) {
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
        content: RichText(
          text: TextSpan(
            children: parseErrorWithFormatting(error, context),
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: errorColor,
        showCloseIcon: true,
        duration: Duration(seconds: 10)));
  }

  static List<TextSpan> parseErrorWithFormatting(dynamic error, BuildContext context) {
    final errorMessage = parseError(error, context);
    
    if (error is LoginError || error is RegistrationError) {
      return _createBoldMessageWithDetails(errorMessage);
    }
    
    return [TextSpan(text: errorMessage)];
  }

  static List<TextSpan> _createBoldMessageWithDetails(String errorMessage) {
    final parts = errorMessage.split('\n\n');
    if (parts.length == 1) {
      return [TextSpan(text: errorMessage, style: TextStyle(fontWeight: FontWeight.bold))];
    }
    
    return [
      TextSpan(text: parts[0], style: TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: '\n\n${parts[1]}'),
    ];
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
    } else if (error is DirectUploadFailureError) {
      return localizations?.errorDirectUploadFailed ??
          'Real-time upload failed due to connectivity issues. Your data has been saved locally. After stopping the recording, you can upload the track manually from the track overview.';
    } else if (error is PermanentAuthenticationError) {
      return localizations?.errorPermanentAuthentication ??
          'Authentication failed permanently. Please log in again to continue uploading data.';
    } else if (error is TrackHasNoGeolocationsException) {
      return localizations?.errorTrackNoGeolocations ??
          'Track has no geolocation data and cannot be uploaded.';
    } else if (error is LoginError) {
      final mainMessage = localizations?.errorLoginFailed ??
          'Login failed. Please check your credentials and try once again later.';
      final details = error.error?.toString() ?? '';
      return details.isNotEmpty
          ? '$mainMessage\n\n$details'
          : mainMessage;
    } else if (error is RegistrationError) {
      final mainMessage = localizations?.errorRegistrationFailed ??
          'Registration failed. Please check your credentials and try once again later.';
      final details = error.error?.toString() ?? '';
      return details.isNotEmpty
          ? '$mainMessage\n\n$details'
          : mainMessage;
    }

    return 'An unknown error occurred.\n Details: ${error.toString()}';
  }

  static void logToConsole(dynamic error, StackTrace stack) {
    debugPrintStack(stackTrace: stack, label: error.toString());
  }
}
