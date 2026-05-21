import 'package:sensebox_bike/services/ble/sensebox_device.dart';

enum ConnectionEventType {
  initialConnectionFailed,
  reconnectionExhausted,
  deviceConnected,
  deviceDisconnected,
  reconnectionStarted,
  reconnectionSucceeded,
}

class ConnectionEvent {
  final ConnectionEventType type;
  final SenseBoxDevice? device;

  const ConnectionEvent({
    required this.type,
    this.device,
  });
}
