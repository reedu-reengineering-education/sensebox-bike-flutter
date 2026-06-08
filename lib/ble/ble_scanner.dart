import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';

const _senseBoxDeviceNamePrefix = 'senseBox';

class BleScanner {
  BleScanner({required this.isScanningNotifier});

  final ValueNotifier<bool> isScanningNotifier;

  final List<BluetoothDevice> devicesList = [];
  final StreamController<List<BluetoothDevice>> _devicesListController =
      StreamController<List<BluetoothDevice>>.broadcast();

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  Stream<List<BluetoothDevice>> get devicesListStream =>
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

    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription =
        FlutterBluePlus.scanResults.listen(_onScanResults);
    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);

    try {
      await FlutterBluePlus.startScan(
        timeout: bleScanTimeout,
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      throw ScanPermissionDenied();
    }

    isScanningNotifier.value = true;

    await _isScanningSubscription?.cancel();
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  Future<void> stopScanning({bool keepScanningIndicator = false}) async {
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = null;
    await _isScanningSubscription?.cancel();
    _isScanningSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (!keepScanningIndicator) {
      isScanningNotifier.value = false;
    }
  }

  Future<void> scanForBox({
    required String name,
    required Future<void> Function(BluetoothDevice device) onDeviceFound,
  }) async {
    await stopScanning();
    await FlutterBluePlus.startScan(withNames: [name]);
    await _scanResultsSubscription?.cancel();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (senseBoxScanResultDisplayName(result) == name) {
          await onDeviceFound(result.device);
          break;
        }
      }
    });
    FlutterBluePlus.cancelWhenScanComplete(_scanResultsSubscription!);
  }

  void _onScanResults(List<ScanResult> results) {
    devicesList
      ..clear()
      ..addAll(senseBoxDevicesFromScanResults(results));
    _emitDevicesList();
  }

  void _emitDevicesList() {
    if (!_devicesListController.isClosed) {
      _devicesListController.add(List<BluetoothDevice>.from(devicesList));
    }
  }

  void dispose() {
    unawaited(_scanResultsSubscription?.cancel());
    unawaited(_isScanningSubscription?.cancel());
    _devicesListController.close();
  }
}

String senseBoxScanResultDisplayName(ScanResult result) {
  final advName = result.advertisementData.advName;
  if (advName.isNotEmpty) {
    return advName;
  }
  return senseBoxDeviceDisplayName(result.device);
}

String senseBoxDeviceDisplayName(BluetoothDevice device) {
  if (device.advName.isNotEmpty) {
    return device.advName;
  }
  return device.platformName;
}

/// Label for the device picker.
String bleDevicePickerLabel(BluetoothDevice device) {
  final name = senseBoxDeviceDisplayName(device);
  if (name.isNotEmpty) {
    return name;
  }
  return device.remoteId.toString();
}

/// All unique devices from a scan (no senseBox name/service filter).
List<BluetoothDevice> devicesFromScanResults(Iterable<ScanResult> results) {
  final devices = <BluetoothDevice>[];
  final seen = <DeviceIdentifier>{};
  for (final result in results) {
    final device = result.device;
    if (seen.contains(device.remoteId)) {
      continue;
    }
    seen.add(device.remoteId);
    devices.add(device);
  }
  return devices;
}

bool isSenseBoxBleScanResult(ScanResult result) {
  return senseBoxScanResultDisplayName(result)
      .startsWith(_senseBoxDeviceNamePrefix);
}

List<BluetoothDevice> senseBoxDevicesFromScanResults(
  Iterable<ScanResult> results,
) {
  final devices = <BluetoothDevice>[];
  final seen = <DeviceIdentifier>{};
  for (final result in results) {
    final device = result.device;
    if (!isSenseBoxBleScanResult(result) || seen.contains(device.remoteId)) {
      continue;
    }
    seen.add(device.remoteId);
    devices.add(device);
  }
  return devices;
}
