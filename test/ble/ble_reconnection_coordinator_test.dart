import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

void main() {
  late BleReconnectionCoordinator coordinator;
  late ValueNotifier<bool> isReconnectingNotifier;
  late MockBluetoothDevice device;
  late StreamController<BluetoothConnectionState> connectionStateController;
  var vibrateOnDisconnect = false;

  setUp(() {
    vibrateOnDisconnect = false;
    isReconnectingNotifier = ValueNotifier(false);
    coordinator = BleReconnectionCoordinator(
      isReconnectingNotifier: isReconnectingNotifier,
      getVibrateOnDisconnect: () => vibrateOnDisconnect,
    );

    device = MockBluetoothDevice();
    connectionStateController =
        StreamController<BluetoothConnectionState>.broadcast();
    when(() => device.connectionState)
        .thenAnswer((_) => connectionStateController.stream);
  });

  tearDown(() {
    coordinator.detach();
    connectionStateController.close();
    isReconnectingNotifier.dispose();
  });

  group('BleReconnectionCoordinator', () {
    test('runs reconnect even when onLinkLost already set the UI notifier',
        () async {
      var reconnectCalls = 0;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () => isReconnectingNotifier.value = true,
        runReconnectSessions: (_) async {
          reconnectCalls++;
          return true;
        },
        onReconnectSucceeded: () {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(reconnectCalls, 1);
      expect(isReconnectingNotifier.value, isFalse);
    });

    test('starts reconnect when link drops unexpectedly', () async {
      var linkLost = false;
      var reconnectCalls = 0;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () => linkLost = true,
        runReconnectSessions: (_) async {
          reconnectCalls++;
          return true;
        },
        onReconnectSucceeded: () {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(linkLost, isTrue);
      expect(reconnectCalls, 1);
      expect(isReconnectingNotifier.value, isFalse);
    });

    test('ignores disconnect while shouldIgnoreDisconnect is true', () async {
      var reconnectCalls = 0;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => true,
        onLinkLost: () {},
        runReconnectSessions: (_) async {
          reconnectCalls++;
          return true;
        },
        onReconnectSucceeded: () {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(reconnectCalls, 0);
      expect(isReconnectingNotifier.value, isFalse);
    });

    test('calls onListenerError when connection stream errors', () async {
      Object? capturedError;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () {},
        runReconnectSessions: (_) async => true,
        onReconnectSucceeded: () {},
        onListenerError: (_, error) async => capturedError = error,
      );

      connectionStateController.addError(Exception('stream failed'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<Exception>());
    });

    test('reset clears reconnecting notifier', () {
      isReconnectingNotifier.value = true;
      coordinator.reset();
      expect(isReconnectingNotifier.value, isFalse);
    });
  });
}
