import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  group('ErrorService', () {
    group('parseError', () {
      late BuildContext mockContext;

      Future<void> initializeContext(WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              mockContext = context;
              return const SizedBox();
            },
          ),
        ));
      }

      testWidgets('returns correct message for LocationPermissionDenied',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          LocationPermissionDenied(),
          mockContext,
        );

        expect(
          message,
          'Please allow the app to access current location of the current device in the phone settings.',
        );
      });

      testWidgets('returns correct message for ScanPermissionDenied',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          ScanPermissionDenied(),
          mockContext,
        );

        expect(
          message,
          'Please allow the app to scan nearby devices in the phone settings.',
        );
      });

      testWidgets('returns correct message for NoSenseBoxSelected',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          NoSenseBoxSelected(),
          mockContext,
        );

        expect(
          message,
          'Please login to your openSenseMap account and select box in order to allow upload sensor data to the cloud.',
        );
      });

      testWidgets('returns unknown error message for other exceptions',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          Exception('Test error'),
          mockContext,
        );

        expect(message, 'An unknown error occurred. Exception: Test error');
      });
    });
  
    group('logToConsole', () {
      test('logs error and stack trace to console', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        // Capture debugPrint output
        final log = <String>[];
        debugPrint = (String? message, {int? wrapWidth}) {
          log.add(message ?? '');
        };

        // Call the method
        ErrorService.logToConsole(error, stackTrace);

        // Restore debugPrint
        debugPrint = debugPrintSynchronously;

        // Verify the output
        expect(log, contains(error.toString()));
      });
    });
  
    group('showUserFeedback', () {
      testWidgets('displays SnackBar with correct message',
          (WidgetTester tester) async {
        // Create a test widget with a ScaffoldMessenger
        await tester.pumpWidget(MaterialApp(
          scaffoldMessengerKey: ErrorService.scaffoldKey,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ErrorService.showUserFeedback(LocationPermissionDenied());
                  },
                  child: const Text('Trigger Error'),
                );
              },
            ),
          ),
        ));

        // Tap the button to trigger the error
        await tester.tap(find.text('Trigger Error'));
        await tester.pump();

        // Verify that the SnackBar is displayed with the correct message
        expect(
          find.text(
              'Please allow the app to access your location in the phone settings.'),
          findsOneWidget,
        );
      });
    });
  });
}
