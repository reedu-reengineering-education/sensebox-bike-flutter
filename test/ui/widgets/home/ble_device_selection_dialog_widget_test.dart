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
    when(() => bleBloc.devicesList).thenReturn([]);
    when(() => bleBloc.devicesListStream).thenAnswer((_) => Stream.value([]));
    when(() => bleBloc.isScanningNotifier).thenReturn(ValueNotifier(false));
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
            scanError: 'Test error',
          ),
        ),
      ),
    );

    expect(find.textContaining('Test error'), findsOneWidget);
  });

  testWidgets('shows loading spinner while scanning', (tester) async {
    when(() => bleBloc.isScanningNotifier).thenReturn(ValueNotifier(true));

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
    const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'TestDevice');
    when(() => bleBloc.devicesList).thenReturn([device]);
    when(() => bleBloc.devicesListStream).thenAnswer((_) => Stream.value([device]));
    var connectCalled = false;
    when(() => bleBloc.connectToDevice(device)).thenAnswer((_) async {
      connectCalled = true;
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

  testWidgets('remembers a device via the row menu', (tester) async {
    const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'TestDevice');
    when(() => bleBloc.devicesList).thenReturn([device]);
    when(() => bleBloc.devicesListStream)
        .thenAnswer((_) => Stream.value([device]));
    when(() => settingsBloc.rememberDevice(any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );
    await tester.pump();

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
    const device = BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'TestDevice');
    when(() => bleBloc.devicesList).thenReturn([device]);
    when(() => bleBloc.devicesListStream)
        .thenAnswer((_) => Stream.value([device]));
    when(() => settingsBloc.rememberedDeviceId).thenReturn(device.id);
    when(() => settingsBloc.forgetRememberedDevice())
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Auto-connects'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Forget device'), findsOneWidget);

    await tester.tap(find.text('Forget device'));
    await tester.pumpAndSettle();

    verify(() => settingsBloc.forgetRememberedDevice()).called(1);
  });
}
