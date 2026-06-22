import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/utils/device_vibration.dart';

enum BleDisconnectReason {
  userRequested,
  connectionFailed,
  retryRelease,
}

/// The connection lifecycle as a single, explicit state. Replaces the previous
/// set of interacting booleans so that connect / reconnect / disconnect flows
/// have exactly one source of truth and invalid combinations are unrepresentable.
enum BleConnectionPhase {
  /// No active link and not attempting one.
  idle,

  /// Initial connection attempt (including the session retry loop).
  connecting,

  /// Link established and a live session is running.
  connected,

  /// Link dropped unexpectedly; the reconnection loop is running.
  reconnecting,
}

class BleBloc with ChangeNotifier {
  BleBloc(
    this.settingsBloc, {
    bool initializePlatformBle = true,
    BlePlatform? platform,
  }) : _platform = platform ?? BlePlatform() {
    _scanner = BleScanner(
      platform: _platform,
      isScanningNotifier: isScanningNotifier,
    );
    _connectionSession = BleConnectionSession(platform: _platform);
    _sessionRetryRunner = BleSessionRetryRunner();
    characteristicStreams = BleCharacteristicStreams(platform: _platform);
    _platform.onLinkStateChanged = _handlePlatformLinkStateChange;
    _reconnectionCoordinator = BleReconnectionCoordinator(platform: _platform);

    if (initializePlatformBle) {
      _refreshBluetoothEnabledStatus();
      _adapterStatusSubscription =
          _platform.statusStream.listen(_onAdapterStatusChanged);
    }
  }

  final SettingsBloc settingsBloc;
  final BlePlatform _platform;

  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);
  final ValueNotifier<BleDevice?> selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<List<BleCharacteristicRef>> availableCharacteristics =
      ValueNotifier([]);
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  late final BleScanner _scanner;
  late final BleReconnectionCoordinator _reconnectionCoordinator;
  late final BleConnectionSession _connectionSession;
  late final BleSessionRetryRunner _sessionRetryRunner;
  late final BleCharacteristicStreams characteristicStreams;

  StreamSubscription<BleAdapterState>? _adapterStatusSubscription;

  List<BleDevice> get devicesList => _scanner.devicesList;
  Stream<List<BleDevice>> get devicesListStream => _scanner.devicesListStream;

  BleDevice? selectedDevice;
  BleDevice? _linkWatchDevice;
  BleConnectionPhase _phase = BleConnectionPhase.idle;
  bool _userInitiatedDisconnect = false;
  bool _appInitiatedTeardown = false;
  bool _scanAfterDisconnect = false;
  bool _linkLostDueToAdapterPowerOff = false;
  String? _vibratedForDisconnectDeviceId;

  bool get isConnected => _phase == BleConnectionPhase.connected;

  /// Single mutator for the connection lifecycle. Driving the UI notifiers from
  /// here (and nowhere else in the bloc) keeps connection state consistent and
  /// makes missed transitions easy to spot.
  void _setPhase(BleConnectionPhase phase) {
    _phase = phase;
    isConnectingNotifier.value = phase == BleConnectionPhase.connecting;
    isReconnectingNotifier.value = phase == BleConnectionPhase.reconnecting;
    notifyListeners();
  }

  Future<void> _refreshBluetoothEnabledStatus() async {
    updateBluetoothStatus(await _platform.isAdapterEnabled());
  }

  void _onAdapterStatusChanged(BleAdapterState status) {
    updateBluetoothStatus(isBluetoothAdapterEnabled(status));
    if (status == BleAdapterState.poweredOff) {
      unawaited(_onBluetoothPoweredOff());
    } else if (status == BleAdapterState.ready) {
      unawaited(_onBluetoothPoweredOn());
    }
  }

  Future<void> _onBluetoothPoweredOff() async {
    if (_userInitiatedDisconnect || selectedDevice == null) {
      return;
    }
    if (_phase != BleConnectionPhase.connected &&
        _phase != BleConnectionPhase.reconnecting) {
      return;
    }

    _linkLostDueToAdapterPowerOff = true;
    final deviceId = selectedDevice!.id;

    // iOS often does not emit a per-device disconnected update when the adapter
    // is toggled off. Tear down the platform link so stale isConnected() cannot
    // block recovery when Bluetooth comes back.
    try {
      await _platform.disconnect(deviceId);
    } catch (_) {
      // Best-effort: subscription cancellation can throw as the radio drops.
    }

    // Adapter-off may not produce connected→disconnected for [_handlePlatformLinkStateChange].
    _maybeVibrateOnUnexpectedDisconnect(deviceId);

    // An in-flight episode already waits for the adapter in [_waitForBluetoothReady].
    if (_reconnectionCoordinator.isReconnectionInProgress) {
      return;
    }
    await _reconnectionCoordinator.notifyUnexpectedLinkLost();
  }

  Future<void> _onBluetoothPoweredOn() async {
    if (_userInitiatedDisconnect || selectedDevice == null) {
      return;
    }
    if (_phase == BleConnectionPhase.connecting) {
      return;
    }
    if (_reconnectionCoordinator.isReconnectionInProgress) {
      return;
    }
    final device = selectedDevice!;
    // Do not trust isConnected() after an adapter power cycle — iOS can keep a
    // stale connected flag until the link is explicitly torn down.
    if (_phase == BleConnectionPhase.connected &&
        _platform.isConnected(device.id) &&
        !_linkLostDueToAdapterPowerOff) {
      return;
    }
    _linkLostDueToAdapterPowerOff = false;
    _setPhase(BleConnectionPhase.reconnecting);
    await _reconnectionCoordinator.notifyUnexpectedLinkLost();
  }

  bool _shouldAbortReconnection() {
    return _reconnectionCoordinator.shouldAbortReconnection;
  }

  void _invalidatePublishedCharacteristics() {
    if (availableCharacteristics.value.isEmpty) {
      return;
    }
    availableCharacteristics.value = [];
    characteristicStreamsVersion.value++;
  }

  void _handlePlatformLinkStateChange(
    String deviceId,
    BleLinkState? previous,
    BleLinkState next,
  ) {
    if (next == BleLinkState.connected) {
      if (_vibratedForDisconnectDeviceId == deviceId) {
        _vibratedForDisconnectDeviceId = null;
      }
      return;
    }
    if (previous != BleLinkState.connected) {
      return;
    }
    _maybeVibrateOnUnexpectedDisconnect(deviceId);
  }

  void _maybeVibrateOnUnexpectedDisconnect(String deviceId) {
    if (!settingsBloc.vibrateOnDisconnect) {
      debugPrint('[BLE] vibrate skipped: setting disabled');
      return;
    }
    if (_userInitiatedDisconnect || _appInitiatedTeardown) {
      return;
    }
    final device = selectedDevice ?? _linkWatchDevice;
    if (device == null || device.id != deviceId) {
      return;
    }
    if (_vibratedForDisconnectDeviceId == deviceId) {
      return;
    }
    _vibratedForDisconnectDeviceId = deviceId;
    debugPrint('[BLE] vibrate on unexpected disconnect $deviceId');
    unawaited(_pulseDisconnectVibration(deviceId));
  }

  Future<void> _pulseDisconnectVibration(String deviceId) async {
    await vibrateDisconnectFeedback();

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_vibratedForDisconnectDeviceId != deviceId) {
      return;
    }
    if (_userInitiatedDisconnect || _appInitiatedTeardown) {
      return;
    }
    if (_platform.isConnected(deviceId)) {
      return;
    }
    debugPrint('[BLE] vibrate retry after disconnect $deviceId');
    await vibrateDisconnectFeedback();
  }

  Future<void> _waitForBluetoothReady() async {
    while (!isBluetoothEnabledNotifier.value) {
      if (_userInitiatedDisconnect || _shouldAbortReconnection()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void updateBluetoothStatus(bool isEnabled) {
    if (isBluetoothEnabledNotifier.value != isEnabled) {
      isBluetoothEnabledNotifier.value = isEnabled;
      notifyListeners();
    }
  }

  Future<void> startScanning() async {
    isScanningNotifier.value = true;
    try {
      final afterDisconnect = _scanAfterDisconnect;
      _scanAfterDisconnect = false;
      await _scanner.startScanning(afterDisconnect: afterDisconnect);
    } catch (_) {
      isScanningNotifier.value = false;
      rethrow;
    }
  }

  Future<void> stopScanning() => _scanner.stopScanning();

  Future<void> scanForNewDevices() async {
    await disconnectDevice(reason: BleDisconnectReason.userRequested);
    await startScanning();
  }

  Future<void> disconnectDevice({
    BleDevice? device,
    BleDisconnectReason reason = BleDisconnectReason.userRequested,
  }) async {
    final target = device ?? selectedDevice;
    final characteristics =
        List<BleCharacteristicRef>.from(availableCharacteristics.value);

    final keepSession = reason == BleDisconnectReason.retryRelease;

    if (reason == BleDisconnectReason.userRequested) {
      _userInitiatedDisconnect = true;
      _linkLostDueToAdapterPowerOff = false;
      _vibratedForDisconnectDeviceId = null;
      _reconnectionCoordinator.cancelReconnection();
    }

    if (!keepSession) {
      isConnectingNotifier.value = true;
    }

    try {
      _invalidatePublishedCharacteristics();

      if (keepSession) {
        _appInitiatedTeardown = true;
      }
      try {
        await _teardownLink(
          target,
          characteristics: characteristics,
          settleAfterDisconnect: keepSession
              ? bleLinkOnlyDisconnectSettleDelay
              : blePostDisconnectSettleDelay,
        );
      } finally {
        if (keepSession) {
          _appInitiatedTeardown = false;
        }
      }

      if (keepSession) {
        notifyListeners();
        return;
      }

      if (reason == BleDisconnectReason.connectionFailed) {
        connectionErrorNotifier.value = true;
        _reconnectionCoordinator.reset();
        _scanAfterDisconnect = true;
      } else {
        connectionErrorNotifier.value = false;
        _scanAfterDisconnect = true;
        await _scanner.stopScanning();
        _scanner.clearDiscoveredDevices();
      }

      if (reason != BleDisconnectReason.userRequested) {
        _userInitiatedDisconnect = false;
      }
    } finally {
      if (!keepSession) {
        selectedDevice = null;
        selectedDeviceNotifier.value = null;
        _linkWatchDevice = null;
        _setPhase(BleConnectionPhase.idle);
      }
    }
  }

  Future<void> connectToId(String id, BuildContext context) async {
    await _connectToBox(id, context);
  }

  Future<void> _connectToBox(String name, BuildContext context) async {
    resetConnectionError();

    await _scanner.scanForBox(
      name: name,
      onDeviceFound: (device) => connectToDevice(device, context),
    );
  }

  Future<void> connectToDevice(BleDevice device, BuildContext context) async {
    _userInitiatedDisconnect = false;
    _linkWatchDevice = device;

    try {
      resetConnectionError();
      _setPhase(BleConnectionPhase.connecting);

      final success = await _connectDeviceWithSessionRetries(
        device,
        maxAttempts: bleInitialConnectMaxAttempts,
        failurePhase: BleConnectionFailurePhase.initialConnect,
      );

      if (success) {
        selectedDevice = device;
        selectedDeviceNotifier.value = selectedDevice;
        _linkWatchDevice = device;
        _setPhase(BleConnectionPhase.connected);
        _attachReconnectionListener(device);
      }
    } catch (e, stack) {
      await disconnectDevice(
        device: device,
        reason: BleDisconnectReason.connectionFailed,
      );
      ErrorService.reportToSentry(
        BleConnectionFailed(BleConnectionFailurePhase.initialConnect, e),
        stack,
      );
    } finally {
      // If we never reached `connected` (failure or exhausted retries) settle
      // back to idle so the UI does not get stuck on a connecting spinner.
      if (_phase != BleConnectionPhase.connected) {
        _linkWatchDevice = null;
        _setPhase(BleConnectionPhase.idle);
      }
    }
  }

  /// Shared connect + establish path for the connect button and auto-reconnect.
  /// When [waitForAdvertising] is true, each attempt (including retries) scans
  /// until the box advertises before calling [BlePlatform.connect].
  Future<bool> _connectDeviceWithSessionRetries(
    BleDevice device, {
    required int maxAttempts,
    required BleConnectionFailurePhase failurePhase,
    bool publishConnectedState = true,
    bool waitForAdvertising = false,
    Future<void> Function()? onExhausted,
  }) async {
    if (failurePhase == BleConnectionFailurePhase.reconnection) {
      await _waitForBluetoothReady();
      if (_shouldAbortReconnection()) {
        return false;
      }
    }
    if (_userInitiatedDisconnect &&
        failurePhase == BleConnectionFailurePhase.initialConnect) {
      return false;
    }

    if (!_platform.isConnected(device.id)) {
      try {
        await _connectLink(
          device,
          waitForAdvertising: waitForAdvertising,
        );
      } catch (_) {
        if (failurePhase == BleConnectionFailurePhase.initialConnect) {
          rethrow;
        }
        return false;
      }
    }

    return _sessionRetryRunner.run(
      device: device,
      maxAttempts: maxAttempts,
      attemptSession: (_, __) => _attemptSingleConnection(
        device,
        publishConnectedState: publishConnectedState,
      ),
      prepareForRetry: (retryDevice) => _prepareForRetry(
        retryDevice,
        waitForAdvertising: waitForAdvertising,
      ),
      onExhausted: onExhausted ??
          () => _onSessionRetriesExhausted(device, failurePhase),
    );
  }

  Future<BleDevice?> _waitForAdvertisingTarget(BleDevice device) {
    return _scanner.waitForAdvertisingDevice(
      device,
      shouldCancel: () =>
          _userInitiatedDisconnect || _shouldAbortReconnection(),
    );
  }

  Future<void> _platformConnect(BleDevice device) async {
    if (isScanningNotifier.value) {
      await stopScanning();
    }
    await _platform.connect(device.id);
  }

  Future<BleDevice> _connectLink(
    BleDevice device, {
    required bool waitForAdvertising,
  }) async {
    var target = device;
    if (waitForAdvertising) {
      final advertised = await _waitForAdvertisingTarget(device);
      if (advertised == null) {
        throw StateError('BLE device not advertising');
      }
      target = advertised;
    }
    await _platformConnect(target);
    return target;
  }

  Future<void> _onSessionRetriesExhausted(
    BleDevice device,
    BleConnectionFailurePhase failurePhase,
  ) async {
    ErrorService.reportToSentry(
      BleConnectionFailed(failurePhase),
      StackTrace.current,
    );
    await disconnectDevice(
      device: device,
      reason: BleDisconnectReason.connectionFailed,
    );
  }

  Future<bool> _attemptSingleConnection(
    BleDevice device, {
    bool publishConnectedState = true,
  }) async {
    if (!_platform.isConnected(device.id)) {
      return false;
    }

    final result = await _connectionSession.establish(
      device,
      streams: characteristicStreams,
    );

    if (!result.success) {
      await disconnectDevice(
        device: device,
        reason: BleDisconnectReason.retryRelease,
      );
      return false;
    }

    availableCharacteristics.value = result.characteristics;
    _userInitiatedDisconnect = false;
    characteristicStreamsVersion.value++;
    // During a reconnect episode keep phase on reconnecting until the
    // coordinator confirms success, so sensors and geolocation are not
    // re-armed on a link that may still be settling.
    if (publishConnectedState) {
      _setPhase(BleConnectionPhase.connected);
    }
    return true;
  }

  Future<void> _prepareForRetry(
    BleDevice device, {
    bool waitForAdvertising = false,
  }) async {
    if (_userInitiatedDisconnect) {
      return;
    }
    if (_phase == BleConnectionPhase.reconnecting && selectedDevice != device) {
      return;
    }
    await _waitForBluetoothReady();
    if (_userInitiatedDisconnect || _shouldAbortReconnection()) {
      return;
    }
    await _sessionRetryRunner.prepareDeviceLink(
      device,
      disconnect: () => disconnectDevice(
        device: device,
        reason: BleDisconnectReason.retryRelease,
      ),
      connect: () => _connectLink(
        device,
        waitForAdvertising: waitForAdvertising,
      ),
    );
  }

  void _attachReconnectionListener(BleDevice device) {
    _userInitiatedDisconnect = false;
    _reconnectionCoordinator.attach(
      device,
      shouldIgnoreDisconnect: () =>
          _userInitiatedDisconnect ||
          _phase == BleConnectionPhase.connecting ||
          _phase == BleConnectionPhase.reconnecting ||
          _appInitiatedTeardown,
      onLinkLost: () {
        // Drop published characteristics immediately so SensorBloc and the UI
        // do not keep listening on stream controllers that teardown is about to
        // close. Each reconnection attempt still rebuilds subscriptions in
        // [BleConnectionSession.establish] via [characteristicStreams.clear].
        _invalidatePublishedCharacteristics();
        _setPhase(BleConnectionPhase.reconnecting);
        _maybeVibrateOnUnexpectedDisconnect(device.id);
      },
      runReconnectSessions: _runReconnectionSessions,
      onReconnectSucceeded: () {
        _userInitiatedDisconnect = false;
        _linkLostDueToAdapterPowerOff = false;
        _setPhase(BleConnectionPhase.connected);
      },
      onReconnectEpisodeEnded: (success) {
        if (success) {
          _attachReconnectionListener(device);
          return;
        }
        if (_userInitiatedDisconnect) {
          return;
        }
        if (_phase == BleConnectionPhase.reconnecting) {
          _setPhase(BleConnectionPhase.idle);
        }
      },
      onListenerError: (device, error) async {
        ErrorService.reportToSentry(
          BleConnectionFailed(BleConnectionFailurePhase.reconnection, error),
          StackTrace.current,
        );
        await disconnectDevice(
          device: device,
          reason: BleDisconnectReason.connectionFailed,
        );
      },
    );
  }

  Future<bool> _runReconnectionSessions(BleDevice device) async {
    if (_shouldAbortReconnection() || selectedDevice != device) {
      return false;
    }
    _linkWatchDevice = device;

    return _connectDeviceWithSessionRetries(
      device,
      maxAttempts: bleMaxReconnectionAttempts,
      failurePhase: BleConnectionFailurePhase.reconnection,
      publishConnectedState: false,
      waitForAdvertising: true,
      onExhausted: () async {
        if (_userInitiatedDisconnect || selectedDevice != device) {
          return;
        }
        await _onSessionRetriesExhausted(
          device,
          BleConnectionFailurePhase.reconnection,
        );
      },
    );
  }

  void resetConnectionError() {
    connectionErrorNotifier.value = false;
    _reconnectionCoordinator.detach();
    _reconnectionCoordinator.reset();
    notifyListeners();
  }

  @visibleForTesting
  void debugSetConnectionPhase(BleConnectionPhase phase) => _setPhase(phase);

  @visibleForTesting
  void debugAttachReconnectionListener(BleDevice device) =>
      _attachReconnectionListener(device);

  @visibleForTesting
  void debugMarkLinkLostDueToAdapterPowerOff() {
    _linkLostDueToAdapterPowerOff = true;
  }

  @visibleForTesting
  Future<void> debugOnBluetoothPoweredOff() => _onBluetoothPoweredOff();

  @visibleForTesting
  Future<void> debugOnBluetoothPoweredOn() => _onBluetoothPoweredOn();

  @override
  void dispose() {
    _adapterStatusSubscription?.cancel();
    _reconnectionCoordinator.detach();
    _scanner.dispose();
    unawaited(characteristicStreams.clear());
    unawaited(_platform.dispose());
    selectedDeviceNotifier.dispose();
    isBluetoothEnabledNotifier.dispose();
    isScanningNotifier.dispose();
    isConnectingNotifier.dispose();
    isReconnectingNotifier.dispose();
    availableCharacteristics.dispose();
    super.dispose();
  }

  Future<void> requestEnableBluetooth() async {
    // On Android 12+ the adapter reports `unauthorized` until the runtime
    // BLUETOOTH_SCAN/CONNECT permissions are granted, which surfaces as a
    // disabled-Bluetooth state. Request those first.
    final permissionsGranted =
        await PermissionService.ensureBluetoothPermissionsGranted();
    await _refreshBluetoothEnabledStatus();
    if (isBluetoothEnabledNotifier.value) {
      return;
    }

    if (!permissionsGranted) {
      // Likely permanently denied; the system Bluetooth toggle won't help, so
      // send the user to the app settings to grant access.
      await PermissionService.openAppSettings();
      await _refreshBluetoothEnabledStatus();
      return;
    }

    // Permissions are in place but the adapter itself is off.
    await PermissionService.openBluetoothSettings();
    await _refreshBluetoothEnabledStatus();
  }

  /// Single teardown primitive for every disconnect path. Clears characteristic
  /// streams and releases the link via [BleConnectionSession.release] (which is
  /// the only disconnect flutter_reactive_ble offers: canceling the
  /// connection-stream subscription). [settleAfterDisconnect] lets the peer drop
  /// the GATT link before any reconnect attempt.
  Future<void> _teardownLink(
    BleDevice? device, {
    required List<BleCharacteristicRef> characteristics,
    required Duration settleAfterDisconnect,
  }) async {
    try {
      await characteristicStreams.clear();
    } catch (_) {}

    if (device != null) {
      try {
        await _connectionSession.release(device);
      } catch (_) {}
    }

    try {
      await characteristicStreams.clear(characteristics: characteristics);
    } catch (_) {}

    if (device != null && settleAfterDisconnect > Duration.zero) {
      await Future<void>.delayed(settleAfterDisconnect);
    }
  }
}
