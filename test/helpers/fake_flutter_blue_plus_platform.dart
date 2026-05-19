import 'dart:async';

import 'package:flutter_blue_plus_platform_interface/flutter_blue_plus_platform_interface.dart';

/// Minimal platform fake so [BleBloc] can be tested on the VM.
final class FakeFlutterBluePlusPlatform extends FlutterBluePlusPlatform {
  FakeFlutterBluePlusPlatform({
    this.connectSucceeds = true,
    this.adapterOn = true,
  }) {
    _adapterStateController = StreamController<BmBluetoothAdapterState>.broadcast();
    _scanResponseController = StreamController<BmScanResponse>.broadcast();
    _connectionStateController =
        StreamController<BmConnectionStateResponse>.broadcast();

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

  final Set<String> _connectedDeviceIds = {};

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

  void dispose() {
    _adapterStateController.close();
    _scanResponseController.close();
    _connectionStateController.close();
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
