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

  Stream<List<BluetoothDevice>> get devicesListStream =>
      _devicesListController.stream;

  Future<void> startScanning() async {
    isScanningNotifier.value = true;

    try {
      await FlutterBluePlus.startScan(timeout: bleScanTimeout);
    } catch (e) {
      isScanningNotifier.value = false;
      throw ScanPermissionDenied();
    }

    FlutterBluePlus.scanResults.listen(_onScanResults);
    FlutterBluePlus.isScanning.listen((scanning) {
      isScanningNotifier.value = scanning;
    });
  }

  Future<void> stopScanning() async {
    await FlutterBluePlus.stopScan();
    isScanningNotifier.value = false;
  }

  Future<void> scanForBox({
    required String name,
    required Future<void> Function(BluetoothDevice device) onDeviceFound,
  }) async {
    await FlutterBluePlus.startScan(withNames: [name]);
    FlutterBluePlus.scanResults.listen((results) async {
      for (final result in results) {
        if (_nameOf(result.device) == name) {
          await onDeviceFound(result.device);
          break;
        }
      }
    });
  }

  void _onScanResults(List<ScanResult> results) {
    devicesList
      ..clear()
      ..addAll(senseBoxDevicesFromScanResults(results));
    _devicesListController.add(devicesList);
  }

  void dispose() {
    _devicesListController.close();
  }
}

String _nameOf(BluetoothDevice device) => device.advName;

List<BluetoothDevice> senseBoxDevicesFromScanResults(
  Iterable<ScanResult> results,
) {
  final devices = <BluetoothDevice>[];
  for (final result in results) {
    if (result.device.platformName.startsWith(_senseBoxDeviceNamePrefix)) {
      devices.add(result.device);
    }
  }
  return devices;
}
