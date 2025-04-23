import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import '../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
  });

  group('ErrorService', () {
    testWidgets('shows SnackBar for LocationPermissionDenied error',
        (WidgetTester tester) async {
      final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
      ErrorService.scaffoldKey = scaffoldKey;

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldKey,
        home: Scaffold( // Add a Scaffold here
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorService.handleError(
                      LocationPermissionDenied(), StackTrace.current);
                },
                child: const Text('Trigger Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pump();

      expect(
        find.text(
            'Please allow the app to access your location in the phone settings.'),
        findsOneWidget,
      );
    });

    testWidgets('shows SnackBar for ScanPermissionDenied error',
        (WidgetTester tester) async {
      final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
      ErrorService.scaffoldKey = scaffoldKey;

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldKey,
        home: Scaffold( // Add a Scaffold here
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorService.handleError(
                      ScanPermissionDenied(), StackTrace.current);
                },
                child: const Text('Trigger Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pump();

      expect(
        find.text(
            'Please allow the app to scan nearby devices in the phone settings.'),
        findsOneWidget,
      );
    });

    testWidgets('shows SnackBar for NoSenseBoxSelected error',
        (WidgetTester tester) async {
      final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
      ErrorService.scaffoldKey = scaffoldKey;

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldKey,
        home: Scaffold( // Add a Scaffold here
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorService.handleError(
                      NoSenseBoxSelected(), StackTrace.current);
                },
                child: const Text('Trigger Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pump();

      expect(
        find.text(
            'Please log in to your openSenseMap account and select a box to upload sensor data to the cloud.'),
        findsOneWidget,
      );
    });

    testWidgets('shows SnackBar for unknown error', (WidgetTester tester) async {
      final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
      ErrorService.scaffoldKey = scaffoldKey;

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: scaffoldKey,
        home: Scaffold( // Add a Scaffold here
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  ErrorService.handleError(Exception('Test error'),
                      StackTrace.current);
                },
                child: const Text('Trigger Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Trigger Error'));
      await tester.pump();

      expect(
        find.text('Unknown error: Exception: Test error'),
        findsOneWidget,
      );
    });
  });
}