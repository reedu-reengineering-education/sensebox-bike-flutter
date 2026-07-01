import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';
import 'package:sensebox_bike/ble/ble_reconnection_coordinator.dart';
import 'ble_test_helpers.dart';
import 'mock_ble_platform.dart';

void main() {
  late MockBlePlatform platform;
  late BleReconnectionCoordinator coordinator;
  late ReconnectionTestSpy spy;
  late StreamController<BleLinkState> connectionStateController;

  setUp(() {
    platform = MockBlePlatform();
    coordinator = BleReconnectionCoordinator(platform: platform);
    spy = ReconnectionTestSpy();

    connectionStateController = StreamController<BleLinkState>.broadcast();
    when(() => platform.connectionState(testBleDevice.id))
        .thenAnswer((_) => connectionStateController.stream);
  });

  tearDown(() {
    coordinator.detach();
    connectionStateController.close();
  });

  Future<void> emitDisconnected() async {
    connectionStateController.add(BleLinkState.disconnected);
    await Future<void>.delayed(Duration.zero);
  }

  group('BleReconnectionCoordinator', () {
    test('reconnects on unexpected disconnect', () async {
      spy.attach(coordinator, testBleDevice);

      await emitDisconnected();

      expect(spy.linkLostCalls, 1);
      expect(spy.reconnectCalls, 1);
      expect(coordinator.canStartReconnectionEpisode(), isTrue);
    });

    test('ignores disconnect while shouldIgnoreDisconnect is true', () async {
      spy.attach(
        coordinator,
        testBleDevice,
        shouldIgnoreDisconnect: () => true,
      );

      await emitDisconnected();

      expect(spy.reconnectCalls, 0);
    });

    test('calls onListenerError when connection stream errors', () async {
      spy.attach(coordinator, testBleDevice);

      connectionStateController.addError(Exception('stream failed'));
      await Future<void>.delayed(Duration.zero);

      expect(spy.listenerError, isA<Exception>());
    });

    test('reset clears in-progress flag', () {
      coordinator.reset();
      expect(coordinator.canStartReconnectionEpisode(), isTrue);
    });

    test('calls onReconnectEpisodeEnded with success result', () async {
      spy.attach(
        coordinator,
        testBleDevice,
        runReconnectSessions: (_) async => false,
      );

      await emitDisconnected();

      expect(spy.episodeSuccess, isFalse);
    });

    test('notifyUnexpectedLinkLost starts reconnect when listener is active',
        () async {
      spy.attach(coordinator, testBleDevice);

      await coordinator.notifyUnexpectedLinkLost();
      await Future<void>.delayed(Duration.zero);

      expect(spy.reconnectCalls, 1);
    });

    test('notifyUnexpectedLinkLost is ignored while episode is in progress',
        () async {
      final gate = Completer<void>();

      spy.attach(
        coordinator,
        testBleDevice,
        runReconnectSessions: (_) async {
          spy.reconnectCalls++;
          await gate.future;
          return true;
        },
      );

      unawaited(coordinator.notifyUnexpectedLinkLost());
      await Future<void>.delayed(Duration.zero);
      await coordinator.notifyUnexpectedLinkLost();
      await Future<void>.delayed(Duration.zero);

      expect(spy.reconnectCalls, 1);
      gate.complete();
    });

    test('abortCurrentEpisode ends an in-flight reconnect loop', () async {
      final gate = Completer<void>();
      var episodeSuccess = true;

      spy.attach(
        coordinator,
        testBleDevice,
        runReconnectSessions: (_) async {
          coordinator.abortCurrentEpisode();
          await gate.future;
          return true;
        },
        onReconnectEpisodeEnded: (success) => episodeSuccess = success,
      );

      unawaited(coordinator.notifyUnexpectedLinkLost());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(episodeSuccess, isFalse);
      expect(coordinator.canStartReconnectionEpisode(), isTrue);
    });
  });
}
