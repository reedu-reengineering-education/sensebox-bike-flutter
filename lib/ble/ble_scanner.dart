import 'dart:async';

import 'package:sensebox_bike/ble/ble_constants.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_uuids.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _senseBoxDeviceNamePrefix = 'senseBox';

class BleScanner {
  BleScanner(this.platform);

  final BlePlatform platform;

  StreamSubscription<BleDevice>? _scanSubscription;
  Timer? _scanTimeoutTimer;
  void Function()? _onScanEnded;
  final Map<String, Set<BleUuid>> _advertisedServices = {};
  final Set<String> _filteredScanMissed = {};

  Stream<List<BleDevice>> scanForDevices() {
    final devices = <BleDevice>[];
    late final StreamController<List<BleDevice>> controller;
    void onEnded() => controller.close();
    controller = StreamController<List<BleDevice>>(
      onListen: () => _startScan(
        (device) {
          if (!isSenseBoxDiscoveredDevice(device)) {
            return;
          }
          final index = devices.indexWhere((entry) => entry.id == device.id);
          index >= 0 ? devices[index] = device : devices.add(device);
          controller.add(List.of(devices));
        },
        onError: controller.addError,
        onEnded: onEnded,
      ),
      onCancel: () {
        if (identical(_onScanEnded, onEnded)) {
          return stopScanning();
        }
        return null;
      },
    );
    return controller.stream;
  }

  Future<BleDevice?> waitForAdvertisingDevice(
    BleDevice device, {
    Duration timeout = bleScanTimeout,
  }) async {
    final filter = _scanFilterFor(device.id);
    ErrorService.logEvent('ble', 'scan for device started', data: {
      'device': device.id,
      'timeoutSeconds': timeout.inSeconds,
      'services': [for (final uuid in filter) '$uuid'],
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
      onEnded: () {
        if (!found.isCompleted) {
          found.complete(null);
        }
      },
      timeout: timeout,
      withServices: filter,
    );

    try {
      final result = await found.future;
      if (result == null && filter.isNotEmpty) {
        _filteredScanMissed.add(device.id);
      } else {
        _filteredScanMissed.remove(device.id);
      }
      ErrorService.logEvent('ble', 'scan for device finished', data: {
        'device': device.id,
        'found': result != null,
      });
      return result;
    } finally {
      await stopScanning();
    }
  }

  Future<void> stopScanning() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    final subscription = _scanSubscription;
    final onEnded = _onScanEnded;
    _scanSubscription = null;
    _onScanEnded = null;
    await subscription?.cancel();
    onEnded?.call();
  }

  void _startScan(
    void Function(BleDevice device) onDevice, {
    required void Function(Object error, StackTrace stackTrace) onError,
    required void Function() onEnded,
    Duration timeout = bleScanTimeout,
    List<BleUuid> withServices = const [],
  }) {
    unawaited(stopScanning());
    _onScanEnded = onEnded;
    _scanSubscription =
        platform.scanForDevices(withServices: withServices).listen(
      (device) {
        _rememberAdvertisedServices(device);
        onDevice(device);
      },
      onError: (Object error, StackTrace stackTrace) {
        ErrorService.logEvent('ble', 'scan failed',
            data: {'error': error}, level: SentryLevel.warning);
        onError(error, stackTrace);
        unawaited(stopScanning());
      },
    );
    _scanTimeoutTimer = Timer(timeout, () => unawaited(stopScanning()));
  }

  List<BleUuid> _scanFilterFor(String deviceId) {
    if (_filteredScanMissed.contains(deviceId)) {
      return const [];
    }
    return [...?_advertisedServices[deviceId]];
  }

  void _rememberAdvertisedServices(BleDevice device) {
    if (device.id.isNotEmpty && device.serviceUuids.isNotEmpty) {
      _advertisedServices
          .putIfAbsent(device.id, () => {})
          .addAll(device.serviceUuids);
    }
  }

  void dispose() {
    unawaited(stopScanning());
  }
}

String bleDevicePickerLabel(BleDevice device) {
  return device.name.isNotEmpty ? device.name : device.id;
}

bool isSenseBoxDiscoveredDevice(BleDevice device) {
  return device.name.startsWith(_senseBoxDeviceNamePrefix);
}
