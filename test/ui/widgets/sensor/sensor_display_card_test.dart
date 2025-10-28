import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_display_card.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_value_display.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';

void main() {
  group('SensorDisplayCard', () {
    late StreamController<List<double>> valueStreamController;
    late List<double> initialValue;

    setUp(() {
      valueStreamController = StreamController<List<double>>();
      initialValue = [0.0];
    });

    tearDown(() {
      valueStreamController.close();
    });

    Widget createTestWidget(SensorDisplayCard card) {
      return MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: card,
        ),
      );
    }

    testWidgets('displays sensor card with title and icon', (WidgetTester tester) async {
      // Arrange
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: true,
        ),
      );

      // Act
      await tester.pumpWidget(createTestWidget(card));

      // Assert
      expect(find.text('Test Sensor'), findsOneWidget);
      expect(find.byIcon(Icons.sensors), findsOneWidget);
    });

    testWidgets('displays initial value correctly', (WidgetTester tester) async {
      // Arrange
      initialValue = [25.5];
      
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(1),
          unit: '°C',
          isValid: true,
        ),
      );

      // Act
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('25.5'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('updates display when stream emits new values', (WidgetTester tester) async {
      // Arrange
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: value[0] != 0.0,
        ),
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Initial value
      expect(find.text('0'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);

      // Act - emit new value
      valueStreamController.add([15.7]);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('16'), findsOneWidget); // Rounded to 0 decimal places
      expect(find.text('cm'), findsOneWidget);
    });

    testWidgets('respects decimal places parameter', (WidgetTester tester) async {
      // Arrange
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        decimalPlaces: 1,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(1),
          unit: '°C',
          isValid: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Initial value
      expect(find.text('0.0'), findsOneWidget);

      // Act - emit new value
      valueStreamController.add([1.5]);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('1.5'), findsOneWidget);
    });

    testWidgets('uses custom shouldRerender function when provided', (WidgetTester tester) async {
      // Arrange
      bool customRerenderCalled = false;
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        shouldRerender: (old, next) {
          customRerenderCalled = true;
          return old[0] != next[0]; // Simple comparison
        },
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Initial value
      expect(find.text('0'), findsOneWidget);

      // Act - emit new value
      valueStreamController.add([1.0]);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('1'), findsOneWidget);
      expect(customRerenderCalled, isTrue);
    });

    testWidgets('handles invalid values with conditional styling', (WidgetTester tester) async {
      // Arrange
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: value[0] != 0.0,
        ),
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Initial value (0.0 - invalid)
      expect(find.text('0'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);

      // Act - emit valid value
      valueStreamController.add([15.0]);
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('15'), findsOneWidget);
      expect(find.text('cm'), findsOneWidget);
    });

    testWidgets('handles empty stream gracefully', (WidgetTester tester) async {
      // Arrange
      final emptyStream = Stream<List<double>>.empty();
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: emptyStream,
        initialValue: initialValue,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: true,
        ),
      );

      // Act & Assert - should not throw
      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget); // Should show initial value
    });

    testWidgets('handles multiple value updates efficiently', (WidgetTester tester) async {
      // Arrange
      final card = SensorDisplayCard(
        title: 'Test Sensor',
        icon: Icons.sensors,
        color: Colors.blue,
        valueStream: valueStreamController.stream,
        initialValue: initialValue,
        decimalPlaces: 0,
        valueBuilder: (context, value) => SensorValueDisplay(
          value: value[0].toStringAsFixed(0),
          unit: 'cm',
          isValid: true,
        ),
      );

      await tester.pumpWidget(createTestWidget(card));
      await tester.pumpAndSettle();

      // Act - emit multiple rapid updates
      valueStreamController.add([1.1]);
      valueStreamController.add([1.2]);
      valueStreamController.add([1.3]);
      valueStreamController.add([2.0]); // This should trigger rerender (different whole number)
      await tester.pumpAndSettle();

      // Assert - should show final value
      expect(find.text('2'), findsOneWidget);
    });
  });
}