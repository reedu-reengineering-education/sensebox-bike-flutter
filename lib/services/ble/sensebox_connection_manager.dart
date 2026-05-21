import 'dart:async';

import 'package:sensebox_bike/services/ble/ble_client.dart';
import 'package:sensebox_bike/services/ble/connection_events.dart';
import 'package:sensebox_bike/services/ble/sensebox_constants.dart';
import 'package:sensebox_bike/services/ble/sensebox_data_service.dart';
import 'package:sensebox_bike/services/ble/sensebox_device.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

typedef ConnectionEventCallback = void Function(ConnectionEvent event);
typedef VibrationCallback = void Function();

class SenseBoxConnectionManager {
  final BleClient _bleClient;
  final SenseBoxDataService _dataService;
  final ConnectionEventCallback onConnectionEvent;
  final VibrationCallback? onDisconnectVibrate;

  final StreamController<List<SenseBoxDevice>> _devicesListController =
      StreamController.broadcast();

  StreamSubscription<List<SenseBoxDevice>>? _scanResultsSubscription;
  StreamSubscription<BleConnectionState>? _reconnectionListener;

  SenseBoxDevice? selectedDevice;
  bool isConnected = false;
  bool isScanning = false;
  bool isConnecting = false;
  bool isReconnecting = false;

  bool _userInitiatedDisconnect = false;
  bool _isInRetryMode = false;
  bool _isReconnecting = false;
  int _reconnectionAttempts = 0;
  bool _hasVibrated = false;

  SenseBoxConnectionManager({
    required BleClient bleClient,
    required SenseBoxDataService dataService,
    required this.onConnectionEvent,
    this.onDisconnectVibrate,
  })  : _bleClient = bleClient,
        _dataService = dataService;

  Stream<List<SenseBoxDevice>> get devicesListStream =>
      _devicesListController.stream;

  Future<void> startScanning() async {
    isScanning = true;
    try {
      await _bleClient.startScan();
    } catch (_) {
      isScanning = false;
      throw ScanPermissionDenied();
    }

    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = _bleClient.scanResultsStream.listen(
      _devicesListController.add,
    );
  }

  Future<void> stopScanning() async {
    await _bleClient.stopScan();
    isScanning = false;
  }

  Future<void> scanForNewDevices() async {
    disconnectDevice();
    isScanning = true;

    try {
      await _bleClient.startScan();
    } catch (_) {
      isScanning = false;
      throw ScanPermissionDenied();
    }

    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = _bleClient.scanResultsStream.listen(
      _devicesListController.add,
    );
  }

  Future<void> connectToId(String id) async {
    await _bleClient.startScan(withNames: [id]);

    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = _bleClient.scanResultsStream.listen(
      (devices) async {
        for (final device in devices) {
          if (device.advName == id || device.displayName == id) {
            await connectToDevice(device);
            break;
          }
        }
      },
    );
  }

  Future<void> connectToDevice(SenseBoxDevice device) async {
    isConnecting = true;

    try {
      if (isScanning) {
        await stopScanning();
      }

      await _bleClient.connect(device.id);

      final success = await _attemptConnectionWithRetries(
        device,
        maxAttempts: 5,
        isReconnection: false,
      );
      isConnected = success;

      if (success) {
        selectedDevice = device.copyWith(isConnected: true);
        _handleDeviceReconnection(device);
        onConnectionEvent(
          ConnectionEvent(
            type: ConnectionEventType.deviceConnected,
            device: selectedDevice,
          ),
        );
      } else {
        selectedDevice = null;
        onConnectionEvent(
          const ConnectionEvent(
            type: ConnectionEventType.initialConnectionFailed,
          ),
        );
      }
    } catch (_) {
      selectedDevice = null;
      isConnected = false;
      onConnectionEvent(
        const ConnectionEvent(
          type: ConnectionEventType.initialConnectionFailed,
        ),
      );
    } finally {
      isConnecting = false;
      _isInRetryMode = false;
    }
  }

  void disconnectDevice() {
    _userInitiatedDisconnect = true;
    _isInRetryMode = false;

    final deviceId = selectedDevice?.id;
    if (deviceId != null) {
      _bleClient.disconnect(deviceId);
    }

    isConnected = false;
    selectedDevice = null;
    _dataService.clearStreams();
    _reconnectionListener?.cancel();
    _reconnectionListener = null;
    resetReconnectionState();
  }

  Future<bool> _attemptConnectionWithRetries(
    SenseBoxDevice device, {
    int maxAttempts = 5,
    bool isReconnection = false,
  }) async {
    return _executeConnectionAttempts(
      device,
      maxAttempts: maxAttempts,
      isReconnection: isReconnection,
      attemptConnection: (device) => _attemptSingleConnection(
        device,
        updateConnectionState: !isReconnection,
      ),
      prepareForRetry: _prepareForRetry,
    );
  }

  Future<bool> _executeConnectionAttempts(
    SenseBoxDevice device, {
    required int maxAttempts,
    required bool isReconnection,
    required Future<bool> Function(SenseBoxDevice) attemptConnection,
    required Future<void> Function(SenseBoxDevice) prepareForRetry,
  }) async {
    _isInRetryMode = true;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        isConnected = false;
      }

      var success = false;
      try {
        success = await attemptConnection(device);
      } catch (_) {
        success = false;
      }

      if (success) {
        _isInRetryMode = false;
        return true;
      }

      if (attempt < maxAttempts - 1) {
        try {
          await prepareForRetry(device);
        } catch (_) {
          // Continue with next attempt.
        }
      }
    }

    _isInRetryMode = false;
    return false;
  }

  Future<bool> _attemptSingleConnection(
    SenseBoxDevice device, {
    bool updateConnectionState = true,
  }) async {
    try {
      _dataService.clearStreams();

      final characteristics = await _bleClient.discoverCharacteristics(
        device.id,
        senseBoxServiceUuid,
      );

      if (characteristics.isEmpty) {
        return false;
      }

      final isValid = await _dataService.validateConnectionProbe(
        device.id,
        characteristics.first,
      );

      if (!isValid) {
        return false;
      }

      await _dataService.startStreaming(device.id, characteristics);

      if (updateConnectionState) {
        isConnected = true;
        _userInitiatedDisconnect = false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepareForRetry(SenseBoxDevice device) async {
    try {
      try {
        await _bleClient.disconnect(device.id);
      } catch (_) {
        // Device might already be disconnected.
      }

      await Future.delayed(configurableReconnectionDelay);
      await _bleClient.connect(device.id);
      await Future.delayed(configurableReconnectionDelay);
    } catch (_) {
      // Let the retry loop continue.
    }
  }

  void _handleDeviceReconnection(SenseBoxDevice device) {
    _reconnectionListener?.cancel();
    _userInitiatedDisconnect = false;
    _hasVibrated = false;
    _reconnectionAttempts = 0;

    _reconnectionListener =
        _bleClient.connectionStateStream(device.id).listen((state) {
      if (state == BleConnectionState.disconnected &&
          !_userInitiatedDisconnect &&
          !_isInRetryMode) {
        if (!_isReconnecting) {
          isConnected = false;
          isReconnecting = true;
          _startReconnectionProcess(device);
        }
      }
    });
  }

  Future<void> _startReconnectionProcess(SenseBoxDevice device) async {
    if (_isReconnecting) {
      if (_reconnectionAttempts >= maxReconnectionAttempts) {
        _isReconnecting = false;
        _reconnectionAttempts = 0;
        _hasVibrated = false;
        isReconnecting = false;
      } else {
        return;
      }
    }

    _isReconnecting = true;
    _isInRetryMode = true;

    if (!_hasVibrated) {
      onDisconnectVibrate?.call();
      _hasVibrated = true;
    }

    onConnectionEvent(
      ConnectionEvent(
        type: ConnectionEventType.reconnectionStarted,
        device: device,
      ),
    );

    final success = await _executeConnectionAttempts(
      device,
      maxAttempts: maxReconnectionAttempts,
      isReconnection: true,
      attemptConnection: (device) async {
        _reconnectionAttempts++;
        return _attemptSingleConnection(
          device,
          updateConnectionState: false,
        );
      },
      prepareForRetry: _prepareForRetry,
    );

    if (success) {
      isConnected = true;
      selectedDevice = device.copyWith(isConnected: true);
      _userInitiatedDisconnect = false;
      _hasVibrated = false;
      _reconnectionAttempts = 0;
      isReconnecting = false;
      _isReconnecting = false;
      _isInRetryMode = false;

      onConnectionEvent(
        ConnectionEvent(
          type: ConnectionEventType.reconnectionSucceeded,
          device: selectedDevice,
        ),
      );
    } else if (!isConnected &&
        _reconnectionAttempts >= maxReconnectionAttempts) {
      selectedDevice = null;
      isConnected = false;
      _dataService.clearStreams();
      _reconnectionListener?.cancel();
      _reconnectionListener = null;
      resetReconnectionState();

      onConnectionEvent(
        const ConnectionEvent(
          type: ConnectionEventType.reconnectionExhausted,
        ),
      );
    }
  }

  void resetReconnectionState() {
    _isReconnecting = false;
    _isInRetryMode = false;
    _reconnectionAttempts = 0;
    _hasVibrated = false;
    isReconnecting = false;
  }

  void dispose() {
    _scanResultsSubscription?.cancel();
    _reconnectionListener?.cancel();
    _devicesListController.close();
  }
}
