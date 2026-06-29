import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

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

  Future<void> startScanning({bool afterDisconnect = false}) async {
    await stopScanning(keepScanningIndicator: true);
    clearDiscoveredDevices();

    if (afterDisconnect) {
      await Future<void>.delayed(blePostDisconnectSettleDelay);
    }

    try {
      _scanSubscription = platform.scanForDevices().listen(_onDiscoveredDevice);
      _scanTimeoutTimer = Timer(bleScanTimeout, () {
        unawaited(stopScanning());
      });
      isScanningNotifier.value = true;
    } catch (_) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      throw ScanPermissionDenied();
    }
  }

  Future<void> stopScanning({bool keepScanningIndicator = false}) async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (!keepScanningIndicator) {
      isScanningNotifier.value = false;
    }
  }

  Future<void> scanForBox({
    required String name,
    required Future<void> Function(BleDevice device) onDeviceFound,
  }) async {
    await stopScanning();
    var matchHandled = false;
    _scanSubscription = platform.scanForDevices().listen((device) async {
      if (matchHandled) {
        return;
      }
      if (deviceDisplayName(device) == name) {
        matchHandled = true;
        await stopScanning();
        await onDeviceFound(device);
      }
    });
    _scanTimeoutTimer = Timer(bleScanTimeout, () {
      unawaited(stopScanning());
    });
    isScanningNotifier.value = true;
  }

  Future<BleDevice?> waitForAdvertisingDevice(
    BleDevice device, {
    required bool Function() shouldCancel,
    Duration timeout = bleScanTimeout,
  }) async {
    await stopScanning();

    final found = Completer<BleDevice?>();
    _scanSubscription = platform.scanForDevices().listen((discovered) {
      final nameMatches = device.name.isNotEmpty &&
          deviceDisplayName(discovered) == deviceDisplayName(device);
      if ((nameMatches || discovered.id == device.id) &&
          !found.isCompleted) {
        found.complete(discovered);
      }
    });
    isScanningNotifier.value = true;

    try {
      return await Future.any<BleDevice?>([
        found.future,
        Future<BleDevice?>.delayed(timeout, () => null),
        _waitUntilCancelled(shouldCancel),
      ]);
    } finally {
      await stopScanning();
    }
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

String deviceDisplayName(BleDevice device) {
  return device.name;
}

String bleDevicePickerLabel(BleDevice device) {
  final name = deviceDisplayName(device);
  if (name.isNotEmpty) {
    return name;
  }
  return device.id;
}

bool isSenseBoxDiscoveredDevice(BleDevice device) {
  return device.name.startsWith(_senseBoxDeviceNamePrefix);
}

List<BleDevice> senseBoxDevicesFromDiscovered(
  Iterable<BleDevice> devices,
) {
  final results = <BleDevice>[];
  final seen = <String>{};
  for (final device in devices) {
    if (!isSenseBoxDiscoveredDevice(device)) {
      continue;
    }
    if (seen.contains(device.id)) {
      continue;
    }
    seen.add(device.id);
    results.add(device);
  }
  return results;
}
