import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _senseBoxDeviceNamePrefix = 'senseBox';

class BleScanner {
  BleScanner({
    required this.platform,
    required this.isScanningNotifier,
  });

  final BlePlatform platform;
  final ValueNotifier<bool> isScanningNotifier;

  final List<BleDevice> devicesList = [];
  final StreamController<List<BleDevice>> _devicesListController =
      StreamController<List<BleDevice>>.broadcast();

  StreamSubscription<BleDevice>? _scanSubscription;
  Timer? _scanTimeoutTimer;

  Stream<List<BleDevice>> get devicesListStream =>
      _devicesListController.stream;

  void clearDiscoveredDevices() {
    devicesList.clear();
    _emitDevicesList();
  }

  Future<void> startScanning() async {
    clearDiscoveredDevices();
    _startScan(
      _onDiscoveredDevice,
      onError: (error, stackTrace) {
        if (!_devicesListController.isClosed) {
          _devicesListController.addError(error, stackTrace);
        }
      },
      timeout: bleScanTimeout,
    );
  }

  Future<void> stopScanning() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    isScanningNotifier.value = false;
  }

  Future<BleDevice?> waitForAdvertisingDevice(
    BleDevice device, {
    required bool Function() shouldCancel,
    Duration timeout = bleScanTimeout,
  }) async {
    ErrorService.logEvent('ble', 'scan for device started', data: {
      'device': device.id,
      'timeoutSeconds': timeout.inSeconds,
    });

    final found = Completer<BleDevice?>();
    _startScan(
      (discovered) {
        final matches = device.id.isNotEmpty
            ? discovered.id == device.id
            : device.name.isNotEmpty && discovered.name == device.name;
        if (matches && !found.isCompleted) {
          found.complete(discovered);
        }
      },
      onError: (error, stackTrace) {
        if (!found.isCompleted) {
          found.completeError(error, stackTrace);
        }
      },
      timeout: timeout,
    );

    try {
      final result = await Future.any<BleDevice?>([
        found.future,
        Future<BleDevice?>.delayed(timeout, () => null),
        _waitUntilCancelled(shouldCancel),
      ]);
      ErrorService.logEvent('ble', 'scan for device finished', data: {
        'device': device.id,
        'found': result != null,
      });
      return result;
    } finally {
      await stopScanning();
    }
  }

  void _startScan(
    void Function(BleDevice device) onDevice, {
    required void Function(Object error, StackTrace stackTrace) onError,
    required Duration timeout,
  }) {
    _scanTimeoutTimer?.cancel();
    unawaited(_scanSubscription?.cancel());
    _scanSubscription = platform.scanForDevices().listen(
      onDevice,
      onError: (Object error, StackTrace stackTrace) {
        ErrorService.logEvent('ble', 'scan failed',
            data: {'error': error}, level: SentryLevel.warning);
        unawaited(stopScanning());
        onError(error, stackTrace);
      },
    );
    _scanTimeoutTimer = Timer(timeout, () => unawaited(stopScanning()));
    isScanningNotifier.value = true;
  }

  Future<BleDevice?> _waitUntilCancelled(bool Function() shouldCancel) async {
    while (!shouldCancel()) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  void _onDiscoveredDevice(BleDevice device) {
    if (!isSenseBoxDiscoveredDevice(device)) {
      return;
    }
    final existingIndex =
        devicesList.indexWhere((entry) => entry.id == device.id);
    if (existingIndex >= 0) {
      devicesList[existingIndex] = device;
    } else {
      devicesList.add(device);
    }
    _emitDevicesList();
  }

  void _emitDevicesList() {
    if (!_devicesListController.isClosed) {
      _devicesListController.add(List<BleDevice>.from(devicesList));
    }
  }

  void dispose() {
    unawaited(_scanSubscription?.cancel());
    _scanTimeoutTimer?.cancel();
    _devicesListController.close();
  }
}

String bleDevicePickerLabel(BleDevice device) {
  return device.name.isNotEmpty ? device.name : device.id;
}

bool isSenseBoxDiscoveredDevice(BleDevice device) {
  return device.name.startsWith(_senseBoxDeviceNamePrefix);
}
