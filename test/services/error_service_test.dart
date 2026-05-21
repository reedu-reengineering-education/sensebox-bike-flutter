import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

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

      testWidgets('returns iOS message for LocationPermissionDenied',
          (WidgetTester tester) async {
        final originalPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await initializeContext(tester);

          final message = ErrorService.parseError(
            LocationPermissionDenied(),
            mockContext,
          );

          expect(
            message,
            AppLocalizations.of(mockContext)!.errorNoLocationAccessIos,
          );
        } finally {
          debugDefaultTargetPlatformOverride = originalPlatform;
        }
      });

      testWidgets('returns Android message for LocationPermissionDenied',
          (WidgetTester tester) async {
        final originalPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await initializeContext(tester);

          final message = ErrorService.parseError(
            LocationPermissionDenied(),
            mockContext,
          );

          expect(
            message,
            AppLocalizations.of(mockContext)!.errorNoLocationAccessAndroid,
          );
        } finally {
          debugDefaultTargetPlatformOverride = originalPlatform;
        }
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
          'To connect with senseBox, please allow the app to scan for nearby devices in the phone settings.',
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
          'To allow upload of sensor data to the cloud, please log in to your openSenseMap account and select the box.',
        );
      });

      testWidgets('returns unknown error message for other exceptions',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          Exception('Test error'),
          mockContext,
        );

        expect(message,
            'An unknown error occurred.\n Details: Exception: Test error');
      });

      testWidgets('returns correct message for ExportDirectoryAccessError',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          ExportDirectoryAccessError(),
          mockContext,
        );

        expect(
          message,
          'Error accessing export directory. Please make sure the app has permission to access the storage.',
        );
      });

      testWidgets('returns correct message for LoginError',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          LoginError('Invalid credentials'),
          mockContext,
        );

        expect(
          message,
          contains(
              'Login failed. Please check your credentials and try once again later.'),
        );
      });

      testWidgets('returns correct message for RegistrationError',
          (WidgetTester tester) async {
        await initializeContext(tester);

        final message = ErrorService.parseError(
          RegistrationError('Registration failed'),
          mockContext,
        );

        expect(
          message,
          contains(
              'Registration failed. Please check your credentials and try once again later.'),
        );
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
        final originalPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          late BuildContext context;
          await tester.pumpWidget(MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            scaffoldMessengerKey: ErrorService.scaffoldKey,
            home: Scaffold(
              body: Builder(
                builder: (builderContext) {
                  context = builderContext;
                  return ElevatedButton(
                    onPressed: () {
                      ErrorService.showUserFeedback(
                        LocationPermissionDenied(),
                      );
                    },
                    child: const Text('Trigger Error'),
                  );
                },
              ),
            ),
          ));

          final expectedMessage =
              AppLocalizations.of(context)!.errorNoLocationAccessAndroid;

          await tester.tap(find.text('Trigger Error'));
          await tester.pump();

          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText() == expectedMessage,
            ),
            findsOneWidget,
          );
        } finally {
          debugDefaultTargetPlatformOverride = originalPlatform;
        }
      });
    });
  });
}
