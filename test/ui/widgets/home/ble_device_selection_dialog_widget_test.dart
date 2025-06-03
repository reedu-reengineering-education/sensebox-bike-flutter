import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import '../../../test_helpers.dart';

class MockBleBloc extends Mock implements BleBloc {}
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
          initialScanError: 'Test error',
        ),
        )
      ),
    );

    expect(find.textContaining('Test error'), findsOneWidget);
  });

  testWidgets('shows loading spinner while scanning', (tester) async {
    when(() => bleBloc.isScanningNotifier).thenReturn(ValueNotifier(true));
    when(() => bleBloc.devicesListStream).thenAnswer((_) => Stream.value([]));
    
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
    when(() => bleBloc.isScanningNotifier).thenReturn(ValueNotifier(false));
    when(() => bleBloc.devicesListStream).thenAnswer((_) => Stream.value([]));
    
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Material(
          child: DeviceSelectionSheet(bleBloc: bleBloc),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('No senseBoxes found'), findsOneWidget); // Adjust to your localization
  });

  testWidgets('shows list of devices and taps to connect', (tester) async {
    final device = MockBluetoothDevice();
    when(() => device.platformName).thenReturn('TestDevice');
    when(() => bleBloc.devicesListStream).thenAnswer((_) => Stream.value([device]));
    bool connectCalled = false;
    when(() => bleBloc.connectToDevice(device, any())).thenAnswer((_) async {
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
}