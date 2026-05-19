enum BleConnectionFailureReason {
  noService,
  noCharacteristics,
  noData,
  invalidData,
  connectionTimeout,
  connectionLost,
  bluetoothError,
}

class BleConnectionResult {
  final bool success;
  final BleConnectionFailureReason? failureReason;

  const BleConnectionResult({
    required this.success,
    this.failureReason,
  });

  factory BleConnectionResult.fullSuccess() {
    return const BleConnectionResult(success: true);
  }

  factory BleConnectionResult.failure({
    required BleConnectionFailureReason reason,
  }) {
    return BleConnectionResult(
      success: false,
      failureReason: reason,
    );
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
