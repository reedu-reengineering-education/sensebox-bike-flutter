import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import '../../../mocks.dart';
import '../../../test_helpers.dart';

class MockBleBloc extends Mock implements BleBloc {}

void main() {
  late MockBleBloc bleBloc;
  late MockSettingsBloc settingsBloc;
  const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'TestDevice');

  setUpAll(() {
    registerFallbackValue(const BleDevice(id: 'fallback', name: 'fallback'));
    initializeTestDependencies();
    disableProviderDebugChecks();
  });

  setUp(() {
    bleBloc = MockBleBloc();
    settingsBloc = MockSettingsBloc();
    when(() => settingsBloc.rememberedDeviceId).thenReturn(null);
    when(() => bleBloc.settingsBloc).thenReturn(settingsBloc);
    when(() => bleBloc.scanForDevices()).thenAnswer((_) => Stream.value([]));
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(child: DeviceSelectionSheet(bleBloc: bleBloc)),
      ),
    );
    await tester.pump();
  }

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
    when(() => bleBloc.scanForDevices())
        .thenAnswer((_) => Stream.error('Test error'));

    await pumpSheet(tester);

    expect(find.textContaining('Test error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows loading spinner while scanning', (tester) async {
    final scan = StreamController<List<BleDevice>>();
    addTearDown(scan.close);
    when(() => bleBloc.scanForDevices()).thenAnswer((_) => scan.stream);

    await pumpSheet(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('shows no devices found once the scan ends', (tester) async {
    await pumpSheet(tester);

    expect(find.textContaining('No senseBoxes found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry starts a new scan', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    verify(() => bleBloc.scanForDevices()).called(2);
  });

  testWidgets('shows list of devices and taps to connect', (tester) async {
    when(() => bleBloc.scanForDevices())
        .thenAnswer((_) => Stream.value([device]));
    when(() => bleBloc.connectToDevice(device)).thenAnswer((_) async {});

    await pumpSheet(tester);
    expect(find.text('TestDevice'), findsOneWidget);

    await tapElement(find.text('TestDevice'), tester);
    verify(() => bleBloc.connectToDevice(device)).called(1);
  });

  testWidgets('remembers a device via the row menu', (tester) async {
    when(() => bleBloc.scanForDevices())
        .thenAnswer((_) => Stream.value([device]));
    when(() => settingsBloc.rememberDevice(any(), any()))
        .thenAnswer((_) async {});

    await pumpSheet(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Remember & auto-connect'), findsOneWidget);

    await tester.tap(find.text('Remember & auto-connect'));
    await tester.pumpAndSettle();

    verify(() => settingsBloc.rememberDevice(device.id, device.name))
        .called(1);
  });

  testWidgets('offers to forget the remembered device via the row menu',
      (tester) async {
    when(() => bleBloc.scanForDevices())
        .thenAnswer((_) => Stream.value([device]));
    when(() => settingsBloc.rememberedDeviceId).thenReturn(device.id);
    when(() => settingsBloc.forgetRememberedDevice())
        .thenAnswer((_) async {});

    await pumpSheet(tester);
    expect(find.text('Auto-connects'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Forget device'), findsOneWidget);

    await tester.tap(find.text('Forget device'));
    await tester.pumpAndSettle();

    verify(() => settingsBloc.forgetRememberedDevice()).called(1);
  });
}
