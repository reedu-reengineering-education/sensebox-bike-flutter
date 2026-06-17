import 'dart:typed_data';

enum BleConnectionFailureReason {
  noService,
  noCharacteristics,
  noData,
  invalidData,
  connectionTimeout,
  connectionLost,
  bluetoothError,
}

class BleCharacteristicProbeResult {
  final String uuid;
  final bool isValid;
  final BleConnectionFailureReason? reason;

  const BleCharacteristicProbeResult({
    required this.uuid,
    required this.isValid,
    this.reason,
  });
}

class BleConnectionResult {
  final bool success;
  final bool needsUserDecision;
  final List<BleCharacteristicProbeResult> probes;
  final BleConnectionFailureReason? failureReason;

  const BleConnectionResult({
    required this.success,
    this.needsUserDecision = false,
    this.probes = const [],
    this.failureReason,
  });

  factory BleConnectionResult.fullSuccess({
    List<BleCharacteristicProbeResult> probes = const [],
  }) {
    return BleConnectionResult(success: true, probes: probes);
  }

  factory BleConnectionResult.needsUserDecision({
    required List<BleCharacteristicProbeResult> probes,
  }) {
    return BleConnectionResult(
      success: false,
      needsUserDecision: true,
      probes: probes,
    );
  }

  factory BleConnectionResult.failure({
    required BleConnectionFailureReason reason,
    List<BleCharacteristicProbeResult> probes = const [],
  }) {
    return BleConnectionResult(
      success: false,
      failureReason: reason,
      probes: probes,
    );
  }

  List<String> get validUuids =>
      probes.where((p) => p.isValid).map((p) => p.uuid).toList();

  List<String> get failedUuids =>
      probes.where((p) => !p.isValid).map((p) => p.uuid).toList();

  static BleConnectionFailureReason aggregateFailureReason(
    List<BleCharacteristicProbeResult> probes,
  ) {
    if (probes.isEmpty) {
      return BleConnectionFailureReason.noData;
    }

    final reasons = probes
        .where((p) => !p.isValid && p.reason != null)
        .map((p) => p.reason!)
        .toList();

    if (reasons.isEmpty) {
      return BleConnectionFailureReason.noData;
    }

    if (reasons.every((r) => r == BleConnectionFailureReason.invalidData)) {
      return BleConnectionFailureReason.invalidData;
    }
    if (reasons.any((r) => r == BleConnectionFailureReason.noData)) {
      return BleConnectionFailureReason.noData;
    }
    return BleConnectionFailureReason.invalidData;
  }

  static BleConnectionFailureReason fromException(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('timeout')) {
      return BleConnectionFailureReason.connectionTimeout;
    }
    if (message.contains('disconnected') ||
        (message.contains('connection') && message.contains('lost'))) {
      return BleConnectionFailureReason.connectionLost;
    }
    return BleConnectionFailureReason.bluetoothError;
  }
}

/// Returns true when a BLE notify/read payload looks like real sensor data.
bool isValidBleCharacteristicPayload(Uint8List data) {
  if (data.isEmpty || data.length < 4) {
    return false;
  }
  return !data.every((byte) => byte == 0);
}
