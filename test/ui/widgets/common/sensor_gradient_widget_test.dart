import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_gradient_widget.dart';

void main() {

  group('getSensorGradientColors', () {
    test('returns red-orange-green gradient for distance sensor', () {
      final colors = getSensorGradientColors('distance');
      expect(colors, equals([Colors.red, Colors.orange, Colors.green]));
    });

    test('returns green-orange-red gradient for other sensors', () {
      expect(getSensorGradientColors('temperature'), 
             equals([Colors.green, Colors.orange, Colors.red]));
      expect(getSensorGradientColors('humidity'), 
             equals([Colors.green, Colors.orange, Colors.red]));
      expect(getSensorGradientColors('overtaking'), 
             equals([Colors.green, Colors.orange, Colors.red]));
      expect(getSensorGradientColors('surface_classification_asphalt'), 
             equals([Colors.green, Colors.orange, Colors.red]));
      expect(getSensorGradientColors('unknown_sensor'), 
             equals([Colors.green, Colors.orange, Colors.red]));
    });
  });

  group('SensorValueRange', () {
    test('formats values correctly with unit', () {
      const range = SensorValueRange(
        minValue: 10.5,
        maxValue: 25.7,
        unit: '°C',
      );
      
      expect(range.formattedMinValue, equals('10.5 °C'));
      expect(range.formattedMaxValue, equals('25.7 °C'));
    });

    test('formats values correctly without unit', () {
      const range = SensorValueRange(
        minValue: 10.5,
        maxValue: 25.7,
        unit: null,
      );
      
      expect(range.formattedMinValue, equals('10.5 '));
      expect(range.formattedMaxValue, equals('25.7 '));
    });
  });

  group('SensorGradientWidget', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    // Helper to create mock SenseBox for testing
    SenseBox createMockSenseBox() {
      return SenseBox(
        sId: 'test-box-id',
        name: 'Test Box',
        sensors: [
          Sensor(
            id: 'temp-sensor',
            title: 'Temperature',
            unit: '°C',
            sensorType: 'HDC1080',
          ),
          Sensor(
            id: 'humidity-sensor',
            title: 'Rel. Humidity',
            unit: '%',
            sensorType: 'HDC1080',
          ),
          Sensor(
            id: 'distance-sensor',
            title: 'Overtaking Distance',
            unit: 'cm',
            sensorType: 'VL53L8CX',
          ),
        ],
      );
    }

    testWidgets('displays gradient container with correct height', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [], // Empty list for basic UI test
        height: 20.0,
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      
      expect(container.constraints?.maxHeight, equals(20.0));
    });

    testWidgets('displays correct gradient colors for distance sensor', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'distance',
        geolocations: [], // Empty list for basic UI test
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors, equals([Colors.red, Colors.orange, Colors.green]));
    });

    testWidgets('displays correct gradient colors for other sensors', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [], // Empty list for basic UI test
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.colors, equals([Colors.green, Colors.orange, Colors.red]));
    });

    testWidgets('applies custom padding', (WidgetTester tester) async {
      final customPadding = const EdgeInsets.all(16.0);
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [], // Empty list for basic UI test
        padding: customPadding,
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding));
      final outerPadding = paddingWidgets.first; // The outer Padding widget
      expect(outerPadding.padding, equals(customPadding));
    });

    testWidgets('handles empty geolocations gracefully', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [],
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      // Should not throw an error and should display infinity values
      expect(find.text('Infinity'), findsOneWidget);
      expect(find.text('-Infinity'), findsOneWidget);
    });

    testWidgets('displays gradient with correct border radius', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [],
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;
      
      expect(borderRadius.topLeft, equals(const Radius.circular(20)));
      expect(borderRadius.topRight, equals(const Radius.circular(20)));
      expect(borderRadius.bottomLeft, equals(const Radius.circular(20)));
      expect(borderRadius.bottomRight, equals(const Radius.circular(20)));
    });

    testWidgets('displays gradient with correct alignment', (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [],
      );

      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient as LinearGradient;
      
      expect(gradient.begin, equals(Alignment.centerLeft));
      expect(gradient.end, equals(Alignment.centerRight));
      expect(gradient.tileMode, equals(TileMode.mirror));
    });

    testWidgets('uses SenseBox data when available',
        (WidgetTester tester) async {
      final mockSenseBox = createMockSenseBox();
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [],
        senseBox: mockSenseBox,
      );
      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      // Should still display infinity values but with SenseBox unit
      expect(find.text('Infinity°C'), findsOneWidget);
      expect(find.text('-Infinity°C'), findsOneWidget);
    });

    testWidgets('falls back to constants when SenseBox is null',
        (WidgetTester tester) async {
      final widget = SensorGradientWidget(
        sensorType: 'temperature',
        geolocations: [],
        senseBox: null, // No SenseBox data
      );
      await tester.pumpWidget(createTestWidget(widget));
      await tester.pumpAndSettle();

      // Should use fallback constants (empty unit when SenseBox is null)
      expect(find.text('Infinity'), findsOneWidget);
      expect(find.text('-Infinity'), findsOneWidget);
    });
  });
}
