import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_characteristic_streams.dart';
import 'package:sensebox_bike/ble/ble_connection_session.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/ble/ble_session_retry_runner.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:vibration/vibration.dart';

@immutable
class BleState {
  const BleState({
    required this.isConnected,
    required this.isBluetoothEnabled,
    required this.isScanning,
    required this.isConnecting,
    required this.isReconnecting,
    required this.selectedDevice,
    required this.availableCharacteristics,
    required this.characteristicStreamsVersion,
    required this.connectionError,
  });

  final bool isConnected;
  final bool isBluetoothEnabled;
  final bool isScanning;
  final bool isConnecting;
  final bool isReconnecting;
  final BleDevice? selectedDevice;
  final List<BleCharacteristicRef> availableCharacteristics;
  final int characteristicStreamsVersion;
  final bool connectionError;
}

class BleBloc extends Cubit<BleState> {
  final SettingsBloc settingsBloc;

  final BlePlatform _platform;
  late final BleScanner _scanner;
  late final BleConnectionSession _session;
  late final BleCharacteristicStreams _streams;
  late final BleReconnectionCoordinator _reconnectionCoordinator;
  late final BleSessionRetryRunner _retryRunner;
  late final ValueNotifier<bool> _isScanningNotifier;

  StreamSubscription<BleAdapterState>? _adapterStateSub;

  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  BleDevice? _selectedDevice;
  List<BleCharacteristicRef> _availableCharacteristics = [];
  int _characteristicStreamsVersion = 0;
  bool _connectionError = false;
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _userInitiatedDisconnect = false;
  bool _hasVibrated = false;

  BleDevice? get selectedDevice => _selectedDevice;
  set selectedDevice(BleDevice? device) => _selectedDevice = device;

  bool get isConnected => _isConnected;
  bool get _isScanning => _isScanningNotifier.value;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleBloc(this.settingsBloc, {BlePlatform? platform})
      : _platform = platform ?? BlePlatform(),
        super(const BleState(
          isConnected: false,
          isBluetoothEnabled: false,
          isScanning: false,
          isConnecting: false,
          isReconnecting: false,
          selectedDevice: null,
          availableCharacteristics: [],
          characteristicStreamsVersion: 0,
          connectionError: false,
        )) {
    _isScanningNotifier = ValueNotifier<bool>(false);
    _scanner = BleScanner(
      platform: _platform,
      isScanningNotifier: _isScanningNotifier,
    );
    _session = BleConnectionSession(platform: _platform);
    _streams = BleCharacteristicStreams(platform: _platform);
    _reconnectionCoordinator = BleReconnectionCoordinator(platform: _platform);
    _retryRunner = BleSessionRetryRunner();

    _isScanningNotifier.addListener(_emitState);

    _adapterStateSub = _platform.statusStream.listen((status) {
      updateBluetoothStatus(isBluetoothAdapterEnabled(status));
    });

    _initializeBluetoothStatus();
  }

  void _emitState() {
    if (!isClosed) {
      emit(BleState(
        isConnected: _isConnected,
        isBluetoothEnabled: _isBluetoothEnabled,
        isScanning: _isScanning,
        isConnecting: _isConnecting,
        isReconnecting: _isReconnecting,
        selectedDevice: _selectedDevice,
        availableCharacteristics:
            List<BleCharacteristicRef>.from(_availableCharacteristics),
        characteristicStreamsVersion: _characteristicStreamsVersion,
        connectionError: _connectionError,
      ));
    }
  }

  Future<void> _initializeBluetoothStatus() async {
    final enabled = await _platform.isAdapterEnabled();
    updateBluetoothStatus(enabled);
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (_isBluetoothEnabled != isEnabled) {
      _isBluetoothEnabled = isEnabled;
      _emitState();
    }
  }

  Future<void> startScanning() async {
    try {
      await _scanner.startScanning();
      _emitState();
    } on ScanPermissionDenied {
      _emitState();
      rethrow;
    }
  }

  Future<void> stopScanning() async {
    await _scanner.stopScanning();
    _emitState();
  }

  Future<void> scanForNewDevices() async {
    disconnectDevice();
    await startScanning();
  }

  Future<void> connectToId(String id, BuildContext context) async {
    resetConnectionError();
    await _scanner.scanForBox(
      name: id,
      onDeviceFound: (device) async {
        await _scanner.stopScanning();
        await connectToDevice(device, context);
      },
    );
  }

  Future<void> connectToDevice(BleDevice device, BuildContext context) async {
    try {
      resetConnectionError();
      _isConnecting = true;
      _emitState();

      if (_isScanning) {
        await _scanner.stopScanning();
      }

      await _platform.connect(device.id);

      final success = await _runInitialConnectionAttempts(device);
      _isConnected = success;

      if (_isConnected) {
        _selectedDevice = device;
        _attachReconnectionCoordinator(device, context);
      } else {
        _selectedDevice = null;
        _handleConnectionError(context: context, isInitialConnection: true);
      }
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
      _selectedDevice = null;
      _isConnected = false;
      _handleConnectionError(context: context, isInitialConnection: true);
    } finally {
      _isConnecting = false;
      _emitState();
    }
  }

  Future<bool> _runInitialConnectionAttempts(BleDevice device) {
    return _retryRunner.run(
      device: device,
      maxAttempts: bleInitialConnectMaxAttempts,
      attemptSession: (device, _) => _establishSession(device),
      prepareForRetry: (device) => _retryRunner.prepareDeviceLink(
        device,
        disconnect: () => _platform.disconnect(device.id),
        connect: () => _platform.connect(device.id),
      ),
    );
  }

  Future<bool> _establishSession(BleDevice device) async {
    final result = await _session.establish(device, streams: _streams);
    if (result.success) {
      _availableCharacteristics = result.characteristics;
      _characteristicStreamsVersion++;
      _emitState();
    }
    return result.success;
  }

  void _attachReconnectionCoordinator(BleDevice device, BuildContext context) {
    _userInitiatedDisconnect = false;
    _hasVibrated = false;

    _reconnectionCoordinator.attach(
      device,
      shouldIgnoreDisconnect: () => _userInitiatedDisconnect,
      onLinkLost: () {
        _isConnected = false;
        _isReconnecting = true;
        _emitState();
        if (!_hasVibrated && settingsBloc.vibrateOnDisconnect) {
          Vibration.vibrate();
          _hasVibrated = true;
        }
      },
      runReconnectSessions: (device) => _retryRunner.run(
        device: device,
        maxAttempts: bleMaxReconnectionAttempts,
        attemptSession: (device, _) async {
          await _platform.connect(device.id);
          return _establishSession(device);
        },
        prepareForRetry: (device) => _retryRunner.prepareDeviceLink(
          device,
          disconnect: () => _platform.disconnect(device.id),
          connect: () => _platform.connect(device.id),
        ),
      ),
      onReconnectSucceeded: () {
        _isConnected = true;
        _isReconnecting = false;
        _hasVibrated = false;
        _emitState();
      },
      onReconnectEpisodeEnded: (success) {
        _isReconnecting = false;
        if (!success) {
          _handleConnectionError(context: context, isInitialConnection: false);
        }
        _emitState();
      },
      onListenerError: (device, error) async {
        _handleConnectionError(context: context, isInitialConnection: false);
      },
    );
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _reconnectionCoordinator.cancelReconnection();
    if (_selectedDevice != null) {
      unawaited(_platform.disconnect(_selectedDevice!.id));
    }
    _isConnected = false;
    _selectedDevice = null;
    _availableCharacteristics = [];
    unawaited(_streams.clear());
    resetConnectionError();
    _emitState();
  }

  void _handleConnectionError({
    required BuildContext context,
    bool isInitialConnection = false,
  }) {
    if (isInitialConnection) {
      _selectedDevice = null;
      _isConnected = false;
      _userInitiatedDisconnect = false;
      _isConnecting = false;
      _connectionError = false;
    } else {
      _selectedDevice = null;
      _isConnected = false;
      _connectionError = true;
      _reconnectionCoordinator.detach();
      unawaited(_streams.clear());
      _isReconnecting = false;
      _hasVibrated = false;
      _isConnecting = false;
    }
    _emitState();
  }

  void resetConnectionError() {
    _connectionError = false;
    _reconnectionCoordinator.cancelReconnection();
    _isReconnecting = false;
    _hasVibrated = false;
    _emitState();
  }

  Stream<List<double>> getCharacteristicStream(String characteristicUuid) {
    return _streams.characteristicStream(characteristicUuid);
  }

  Future<void> requestEnableBluetooth() async {
    await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
  }

  @override
  Future<void> close() async {
    _reconnectionCoordinator.detach();
    _isScanningNotifier.removeListener(_emitState);
    _isScanningNotifier.dispose();
    await _adapterStateSub?.cancel();
    _scanner.dispose();
    await _streams.clear();
    await _platform.dispose();
    return super.close();
  }

  void dispose() {
    unawaited(close());
  }
}
