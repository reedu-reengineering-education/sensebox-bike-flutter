import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

enum BleStatus { connected, disconnected, connecting, unknown }

class BleService {
  final StreamController<BleStatus> _controller = 
      StreamController<BleStatus>.broadcast();

  Stream<BleStatus> get statusStream => _controller.stream;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _connectionSubscription;
  
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _controller.add(BleStatus.connecting);
      if (_connectedDevice != null) {
        await disconnectDevice();
      }
      await device.connect();
      _connectedDevice = device;
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _controller.add(BleStatus.connected);
        } else if (state == BluetoothConnectionState.disconnected) {
          _controller.add(BleStatus.disconnected);
        } else {
          _controller.add(BleStatus.unknown);
        }
      });
    } catch (e) {
      _controller.add(BleStatus.disconnected);
    }
  }
  
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }
      _connectionSubscription?.cancel();
      _controller.add(BleStatus.disconnected);
    } catch (e) {}
  }
  
  BluetoothDevice? get connectedDevice => _connectedDevice;
  
  void dispose() {
    _connectionSubscription?.cancel();
    _controller.close();
  }
}