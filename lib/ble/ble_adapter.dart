import 'package:flutter_blue_plus/flutter_blue_plus.dart';

bool isBluetoothAdapterEnabled(BluetoothAdapterState state) =>
    state == BluetoothAdapterState.on;

class BleAdapter {
  void configure() {
    FlutterBluePlus.setLogLevel(LogLevel.error);
  }

  Future<bool> isEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return isBluetoothAdapterEnabled(state);
  }

  Future<void> requestEnable() => FlutterBluePlus.turnOn();
}
