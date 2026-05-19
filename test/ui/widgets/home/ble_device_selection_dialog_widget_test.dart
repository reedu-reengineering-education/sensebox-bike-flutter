import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/ble_connection_phase.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import '../../../mocks.dart';
import '../../../test_helpers.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class FakeBuildContext extends Fake implements BuildContext {}

void main() {
  late MockBleBloc bleBloc;

  setUpAll(() {
    registerFallbackValue(MockBluetoothDevice());
    registerFallbackValue(FakeBuildContext());
    initializeTestDependencies();
    disableProviderDebugChecks();
  });

  setUp(() {
    bleBloc = MockBleBloc();
  });

  tearDown(() {
    bleBloc.dispose();
  });

  testWidgets('shows dialog title', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDeviceSelectionDialog(context, bleBloc),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap to connect'), findsOneWidget);
  });

  testWidgets('shows scan error', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(
            bleBloc: bleBloc,
            initialScanError: 'Test error',
          ),
        ),
      ),
    );

    expect(find.textContaining('Test error'), findsOneWidget);
  });

  testWidgets('shows loading spinner while scanning', (tester) async {
    bleBloc.isScanningNotifier.value = true;

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows no devices found message', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('No senseBoxes found'), findsOneWidget);
  });

  testWidgets('shows list of devices and taps to connect', (tester) async {
    final device = MockBluetoothDevice();
    when(() => device.platformName).thenReturn('TestDevice');
    bleBloc.discoveredDevicesNotifier.value = [device];
    var connectCalled = false;
    when(() => bleBloc.connectToDevice(device)).thenAnswer((_) async {
      connectCalled = true;
      return BleConnectionResult.fullSuccess();
    });

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('TestDevice'), findsOneWidget);

    await tapElement(find.text('TestDevice'), tester);
    expect(connectCalled, isTrue);
  });

  testWidgets('shows connecting spinner while connect is pending',
      (tester) async {
    final device = MockBluetoothDevice();
    when(() => device.platformName).thenReturn('TestDevice');
    bleBloc.discoveredDevicesNotifier.value = [device];

    final connectCompleter = Completer<BleConnectionResult>();
    when(() => bleBloc.connectToDevice(device)).thenAnswer((_) async {
      return connectCompleter.future;
    });

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('TestDevice'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    connectCompleter.complete(BleConnectionResult.fullSuccess());
    await tester.pumpAndSettle();
  });

  testWidgets('shows connection attempt failed dialog on failed connect',
      (tester) async {
    final device = MockBluetoothDevice();
    when(() => device.platformName).thenReturn('TestDevice');
    bleBloc.discoveredDevicesNotifier.value = [device];
    when(() => bleBloc.connectToDevice(device)).thenAnswer((_) async {
      return BleConnectionResult.failure(
        reason: BleConnectionFailureReason.connectionTimeout,
      );
    });

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showDeviceSelectionDialog(context, bleBloc),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('TestDevice'));
    await tester.pumpAndSettle();

    expect(find.text('Connection attempt failed'), findsOneWidget);
    expect(
      find.textContaining('could not connect to the senseBox in time'),
      findsOneWidget,
    );
  });
}
