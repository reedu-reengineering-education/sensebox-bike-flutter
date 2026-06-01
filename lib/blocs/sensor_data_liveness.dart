import 'dart:async';

import 'package:flutter/foundation.dart';

class SensorDataLiveness {
  SensorDataLiveness({required this.noDataTimeout});

  final Duration noDataTimeout;
  final ValueNotifier<bool> hasValidDataNotifier = ValueNotifier(false);

  DateTime? _lastValidDataTimestamp;
  Timer? _staleDataTimer;
  StreamController<void>? _firstValidDataController;

  bool get hasValidData => hasValidDataNotifier.value;
  DateTime? get lastValidDataTimestamp => _lastValidDataTimestamp;

  void resetTracking() {
    _lastValidDataTimestamp = null;
    _staleDataTimer?.cancel();
    _staleDataTimer = null;
    hasValidDataNotifier.value = false;
    _firstValidDataController?.close();
    _firstValidDataController = null;
  }

  void markValidDataSeen() {
    _lastValidDataTimestamp = DateTime.now().toUtc();

    if (!hasValidDataNotifier.value) {
      hasValidDataNotifier.value = true;
      _firstValidDataController?.add(null);
    }

    _restartStaleDataTimer();
  }

  Future<bool> waitForFirstValidData(Duration timeout) async {
    if (hasValidDataNotifier.value) {
      return true;
    }

    _firstValidDataController ??= StreamController<void>.broadcast();

    try {
      await _firstValidDataController!.stream.first.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  void _restartStaleDataTimer() {
    _staleDataTimer?.cancel();
    _staleDataTimer = Timer(noDataTimeout, () {
      hasValidDataNotifier.value = false;
    });
  }

  void dispose() {
    _staleDataTimer?.cancel();
    _firstValidDataController?.close();
    hasValidDataNotifier.dispose();
  }
}
