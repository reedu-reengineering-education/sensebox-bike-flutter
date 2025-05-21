import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/services/ble_service.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockConnectionStateStream extends Mock implements Stream<BluetoothConnectionState> {}

void main() {
  late BleService bleService;
  late MockBluetoothDevice mockDevice;
  late StreamController<BluetoothConnectionState> connectionStateController;

  setUp(() {
    bleService = BleService();
    mockDevice = MockBluetoothDevice();
    connectionStateController = StreamController<BluetoothConnectionState>.broadcast();

    // Mock the connectionState stream
    when(() => mockDevice.connectionState).thenAnswer((_) => connectionStateController.stream);
    // Mock connect/disconnect
    when(() => mockDevice.connect()).thenAnswer((_) async {});
    when(() => mockDevice.disconnect()).thenAnswer((_) async {});
  });

  tearDown(() {
    connectionStateController.close();
    bleService.dispose();
  });

  test('connectToDevice sets status to connecting and then connected', () async {
    final statuses = <BleStatus>[];
    bleService.statusStream.listen(statuses.add);

    await bleService.connectToDevice(mockDevice);
    // Simulate device connected
    connectionStateController.add(BluetoothConnectionState.connected);
    await Future.delayed(Duration.zero);

    expect(statuses.first, BleStatus.connecting);
    expect(statuses.last, BleStatus.connected);
    expect(bleService.connectedDevice, mockDevice);
  });

  test('connectToDevice sets status to disconnected on error', () async {
    final errorDevice = MockBluetoothDevice();
    when(() => errorDevice.connectionState).thenThrow(Exception('fail'));
    when(() => errorDevice.connect()).thenThrow(Exception('fail'));

    final statuses = <BleStatus>[];
    bleService.statusStream.listen(statuses.add);

    await bleService.connectToDevice(errorDevice);
    await Future.delayed(Duration.zero);

    expect(statuses, contains(BleStatus.disconnected));
    expect(bleService.connectedDevice, isNull);
  });

  test('disconnectDevice sets status to disconnected and clears device', () async {
    final statuses = <BleStatus>[];
    bleService.statusStream.listen(statuses.add);

    await bleService.connectToDevice(mockDevice);
    connectionStateController.add(BluetoothConnectionState.connected);
    await Future.delayed(Duration.zero);

    await bleService.disconnectDevice();
    await Future.delayed(Duration.zero);

    expect(statuses.last, BleStatus.disconnected);
    expect(bleService.connectedDevice, isNull);
  });
}