import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'mock_ble_platform.dart';

void main() {
  late MockBlePlatform platform;
  late BleReconnectionCoordinator coordinator;
  late ValueNotifier<bool> isReconnectingNotifier;
  late BleDevice device;
  late StreamController<BleLinkState> connectionStateController;

  setUp(() {
    platform = MockBlePlatform();
    isReconnectingNotifier = ValueNotifier(false);
    coordinator = BleReconnectionCoordinator(
      platform: platform,
      isReconnectingNotifier: isReconnectingNotifier,
    );

    device = const BleDevice(id: 'AA:BB:CC:DD:EE:01', name: 'senseBox:test');
    connectionStateController = StreamController<BleLinkState>.broadcast();
    when(() => platform.connectionState(device.id))
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
        onReconnectEpisodeEnded: (_) {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BleLinkState.disconnected);
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
        onReconnectEpisodeEnded: (_) {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BleLinkState.disconnected);
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
        onReconnectEpisodeEnded: (_) {},
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BleLinkState.disconnected);
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
        onReconnectEpisodeEnded: (_) {},
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

    test('calls onReconnectEpisodeEnded with success result', () async {
      bool? episodeSuccess;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () {},
        runReconnectSessions: (_) async => false,
        onReconnectSucceeded: () {},
        onReconnectEpisodeEnded: (success) => episodeSuccess = success,
        onListenerError: (_, __) async {},
      );

      connectionStateController.add(BleLinkState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(episodeSuccess, isFalse);
    });

    test('notifyUnexpectedLinkLost starts reconnect when listener is active',
        () async {
      var reconnectCalls = 0;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () {},
        runReconnectSessions: (_) async {
          reconnectCalls++;
          return true;
        },
        onReconnectSucceeded: () {},
        onReconnectEpisodeEnded: (_) {},
        onListenerError: (_, __) async {},
      );

      await coordinator.notifyUnexpectedLinkLost();
      await Future<void>.delayed(Duration.zero);

      expect(reconnectCalls, 1);
    });

    test('notifyUnexpectedLinkLost is ignored while episode is in progress',
        () async {
      final gate = Completer<void>();
      var reconnectCalls = 0;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () {},
        runReconnectSessions: (_) async {
          reconnectCalls++;
          await gate.future;
          return true;
        },
        onReconnectSucceeded: () {},
        onReconnectEpisodeEnded: (_) {},
        onListenerError: (_, __) async {},
      );

      unawaited(coordinator.notifyUnexpectedLinkLost());
      await Future<void>.delayed(Duration.zero);
      await coordinator.notifyUnexpectedLinkLost();
      await Future<void>.delayed(Duration.zero);

      expect(reconnectCalls, 1);
      gate.complete();
    });

    test('abortCurrentEpisode ends an in-flight reconnect loop', () async {
      final gate = Completer<void>();
      var episodeSuccess = true;

      coordinator.attach(
        device,
        shouldIgnoreDisconnect: () => false,
        onLinkLost: () {},
        runReconnectSessions: (_) async {
          coordinator.abortCurrentEpisode();
          await gate.future;
          return true;
        },
        onReconnectSucceeded: () {},
        onReconnectEpisodeEnded: (success) => episodeSuccess = success,
        onListenerError: (_, __) async {},
      );

      unawaited(coordinator.notifyUnexpectedLinkLost());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(episodeSuccess, isFalse);
      expect(coordinator.isReconnectionInProgress, isFalse);
    });
  });
}
