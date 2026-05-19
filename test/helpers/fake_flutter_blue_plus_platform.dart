import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/sensors/temperature_sensor.dart';

/// Minimal platform fake so [BleBloc] can be tested on the VM.
final class FakeFlutterBluePlusPlatform extends FlutterBluePlusPlatform {
  FakeFlutterBluePlusPlatform({
    this.connectSucceeds = true,
    this.adapterOn = true,
  }) {
    _adapterStateController =
        StreamController<BmBluetoothAdapterState>.broadcast();
    _scanResponseController = StreamController<BmScanResponse>.broadcast();
    _connectionStateController =
        StreamController<BmConnectionStateResponse>.broadcast();
    _discoveredServicesController =
        StreamController<BmDiscoverServicesResult>.broadcast();
    _descriptorWrittenController =
        StreamController<BmDescriptorData>.broadcast();

    if (adapterOn) {
      _emitAdapterState(BmAdapterStateEnum.on);
    }
  }

  final bool connectSucceeds;
  final bool adapterOn;

  late final StreamController<BmBluetoothAdapterState> _adapterStateController;
  late final StreamController<BmScanResponse> _scanResponseController;
  late final StreamController<BmConnectionStateResponse>
      _connectionStateController;
  late final StreamController<BmDiscoverServicesResult>
      _discoveredServicesController;
  late final StreamController<BmDescriptorData> _descriptorWrittenController;

  static final Guid _cccdUuid =
      Guid('00002902-0000-1000-8000-00805f9b34fb');

  final Set<String> _connectedDeviceIds = {};

  static BmCharacteristicProperties get _notifyProperties =>
      BmCharacteristicProperties(
        broadcast: false,
        read: false,
        writeWithoutResponse: false,
        write: false,
        notify: true,
        indicate: false,
        authenticatedSignedWrites: false,
        extendedProperties: false,
        notifyEncryptionRequired: false,
        indicateEncryptionRequired: false,
      );

  static List<BmBluetoothService> senseBoxServicesFor(DeviceIdentifier remoteId) {
    final serviceUuid = Guid(senseBoxServiceUUID.str);
    final characteristicUuid =
        Guid(TemperatureSensor.sensorCharacteristicUuid);

    return [
      BmBluetoothService(
        remoteId: remoteId,
        serviceUuid: serviceUuid,
        primaryServiceUuid: null,
        characteristics: [
          BmBluetoothCharacteristic(
            remoteId: remoteId,
            serviceUuid: serviceUuid,
            characteristicUuid: characteristicUuid,
            primaryServiceUuid: null,
            descriptors: const [],
            properties: _notifyProperties,
          ),
        ],
      ),
    ];
  }

  void emitScanResult({
    required String remoteId,
    required String platformName,
    String advName = '',
  }) {
    _scanResponseController.add(
      BmScanResponse(
        advertisements: [
          BmScanAdvertisement(
            remoteId: DeviceIdentifier(remoteId),
            platformName: platformName,
            advName: advName.isEmpty ? platformName : advName,
            connectable: true,
            txPowerLevel: null,
            appearance: null,
            manufacturerData: const {},
            serviceData: const {},
            serviceUuids: const [],
            rssi: -50,
          ),
        ],
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
  }

  void _emitAdapterState(BmAdapterStateEnum state) {
    _adapterStateController.add(BmBluetoothAdapterState(adapterState: state));
  }

  @override
  Stream<BmBluetoothAdapterState> get onAdapterStateChanged =>
      _adapterStateController.stream;

  @override
  Stream<BmScanResponse> get onScanResponse => _scanResponseController.stream;

  @override
  Stream<BmConnectionStateResponse> get onConnectionStateChanged =>
      _connectionStateController.stream;

  @override
  Stream<BmDiscoverServicesResult> get onDiscoveredServices =>
      _discoveredServicesController.stream;

  @override
  Stream<BmDescriptorData> get onDescriptorWritten =>
      _descriptorWrittenController.stream;

  @override
  Future<BmBluetoothAdapterState> getAdapterState(
    BmBluetoothAdapterStateRequest request,
  ) async {
    return BmBluetoothAdapterState(
      adapterState:
          adapterOn ? BmAdapterStateEnum.on : BmAdapterStateEnum.off,
    );
  }

  @override
  Future<bool> setOptions(BmSetOptionsRequest request) async => true;

  @override
  Future<bool> setLogLevel(BmSetLogLevelRequest request) async => true;

  @override
  Future<bool> startScan(BmScanSettings request) async => true;

  @override
  Future<bool> stopScan(BmStopScanRequest request) async => true;

  @override
  Future<bool> connect(BmConnectRequest request) async {
    if (!connectSucceeds) {
      return false;
    }

    _connectedDeviceIds.add(request.remoteId.str);
    _connectionStateController.add(
      BmConnectionStateResponse(
        remoteId: request.remoteId,
        connectionState: BmConnectionStateEnum.connected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );
    return true;
  }

  @override
  Future<bool> disconnect(BmDisconnectRequest request) async {
    _connectedDeviceIds.remove(request.remoteId.str);
    _connectionStateController.add(
      BmConnectionStateResponse(
        remoteId: request.remoteId,
        connectionState: BmConnectionStateEnum.disconnected,
        disconnectReasonCode: null,
        disconnectReasonString: null,
      ),
    );
    return true;
  }

  @override
  Future<bool> discoverServices(
    BmDiscoverServicesRequest request,
  ) async {
    if (!_connectedDeviceIds.contains(request.remoteId.str)) {
      _discoveredServicesController.add(
        BmDiscoverServicesResult(
          remoteId: request.remoteId,
          services: const [],
          success: false,
          errorCode: 1,
          errorString: 'not connected',
        ),
      );
      return false;
    }

    _discoveredServicesController.add(
      BmDiscoverServicesResult(
        remoteId: request.remoteId,
        services: senseBoxServicesFor(request.remoteId),
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  @override
  Future<bool> setNotifyValue(BmSetNotifyValueRequest request) async {
    _descriptorWrittenController.add(
      BmDescriptorData(
        remoteId: request.remoteId,
        serviceUuid: request.serviceUuid,
        characteristicUuid: request.characteristicUuid,
        descriptorUuid: _cccdUuid,
        primaryServiceUuid: request.primaryServiceUuid,
        value: Uint8List.fromList([1, 0]),
        success: true,
        errorCode: 0,
        errorString: '',
      ),
    );
    return true;
  }

  void dispose() {
    _adapterStateController.close();
    _scanResponseController.close();
    _connectionStateController.close();
    _discoveredServicesController.close();
    _descriptorWrittenController.close();
  }
}

void installFakeFlutterBluePlusPlatform([
  FakeFlutterBluePlusPlatform? platform,
]) {
  FlutterBluePlusPlatform.instance =
      platform ?? FakeFlutterBluePlusPlatform();
}

void resetFlutterBluePlusPlatform() {
  FlutterBluePlusPlatform.instance = FakeFlutterBluePlusPlatform();
}
