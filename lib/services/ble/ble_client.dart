import 'package:sensebox_bike/services/ble/sensebox_constants.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';

enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class BleCharacteristicRef {
  final String serviceUuid;
  final String characteristicUuid;

  const BleCharacteristicRef({
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCharacteristicRef &&
          serviceUuid == other.serviceUuid &&
          characteristicUuid == other.characteristicUuid;

  @override
  int get hashCode => Object.hash(serviceUuid, characteristicUuid);
}

abstract class BleClient {
  Stream<bool> get isAdapterEnabledStream;

  Future<bool> isAdapterEnabled();

  Future<void> requestEnableBluetooth();

  Stream<bool> get isScanningStream;

  Future<void> startScan({
    Duration timeout = deviceConnectTimeout,
    List<String>? withNames,
  });

  Future<void> stopScan();

  Stream<List<SenseBoxDevice>> get scanResultsStream;

  Future<void> connect(String deviceId, {Duration? timeout});

  Future<void> disconnect(String deviceId);

  Stream<BleConnectionState> connectionStateStream(String deviceId);

  Future<List<BleCharacteristicRef>> discoverCharacteristics(
    String deviceId,
    String serviceUuid,
  );

  Stream<List<int>> subscribeToCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  );

  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    BleCharacteristicRef characteristic,
  );

  void dispose();
}
