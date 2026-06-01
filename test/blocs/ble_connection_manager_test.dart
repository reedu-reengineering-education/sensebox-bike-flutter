import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/ble_connection_manager.dart';
import 'package:sensebox_bike/blocs/ble_connection_state.dart';
import '../mocks.dart';

void main() {
  group('BleConnectionManager', () {
    late BleConnectionManager manager;
    late MockBluetoothDevice device;

    setUpAll(() {
      registerFallbackValue(FakeBuildContext());
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      manager = BleConnectionManager(
        deviceConnectTimeout: const Duration(milliseconds: 10),
        retryDelay: Duration.zero,
      );
      device = MockBluetoothDevice();

      when(() => device.disconnect()).thenAnswer((_) async {});
      when(() => device.connect(timeout: any(named: 'timeout')))
          .thenAnswer((_) async {});
    });


    Future<({bool success, int retries, bool? isInitialConnection})> run({
      int maxAttempts = 3,
      bool isReconnection = false,
      int? succeedOnAttempt,
      bool withContext = false,
    }) async {
      var attemptCount = 0;
      var retryCount = 0;
      bool? capturedIsInitialConnection;

      final success = await manager.attemptConnectionWithRetries(
        device,
        context: withContext ? FakeBuildContext() : null,
        maxAttempts: maxAttempts,
        isReconnection: isReconnection,
        attemptConnection: (_, __) async {
          attemptCount++;
          if (succeedOnAttempt != null && attemptCount == succeedOnAttempt) {
            return true;
          }
          return false;
        },
        handleError: ({required context, bool isInitialConnection = false}) {
          capturedIsInitialConnection = isInitialConnection;
        },
        onRetryAttempt: () => retryCount++,
      );

      return (
        success: success,
        retries: retryCount,
        isInitialConnection: capturedIsInitialConnection,
      );
    }

    test('succeeds on first attempt – no retries, no prep calls', () async {
      final context = FakeBuildContext();
      var attemptCount = 0;
      var retryCount = 0;
      var handleErrorCalled = false;

      final success = await manager.attemptConnectionWithRetries(
        device,
        context: context,
        maxAttempts: 3,
        attemptConnection: (d, ctx) async {
          attemptCount++;
          expect(d, same(device));
          expect(ctx, same(context));
          return true;
        },
        handleError: ({required context, bool isInitialConnection = false}) =>
            handleErrorCalled = true,
        onRetryAttempt: () => retryCount++,
      );

      expect(success, isTrue);
      expect(attemptCount, 1);
      expect(retryCount, 0);
      expect(handleErrorCalled, isFalse);
      verifyNever(() => device.disconnect());
      verifyNever(() => device.connect(timeout: any(named: 'timeout')));
    });

    test('retries between failures and succeeds on attempt 3', () async {
      final result = await run(maxAttempts: 3, succeedOnAttempt: 3);

      expect(result.success, isTrue);
      expect(result.retries, 2);
      verify(() => device.disconnect()).called(2);
      verify(() => device.connect(timeout: any(named: 'timeout'))).called(2);
    });

    test('treats thrown attempt exception as failure and retries', () async {
      var attemptCount = 0;

      final success = await manager.attemptConnectionWithRetries(
        device,
        maxAttempts: 2,
        attemptConnection: (_, __) async {
          attemptCount++;
          if (attemptCount == 1) throw Exception('transient failure');
          return true;
        },
        handleError: ({required context, bool isInitialConnection = false}) =>
            fail('handleError must not be called on eventual success'),
        onRetryAttempt: () {},
      );

      expect(success, isTrue);
      expect(attemptCount, 2);
      verify(() => device.disconnect()).called(1);
      verify(() => device.connect(timeout: any(named: 'timeout'))).called(1);
    });

    test('exhausts all attempts and calls handleError(isInitialConnection: true)',
        () async {
      final result = await run(
        maxAttempts: 2,
        isReconnection: false,
        succeedOnAttempt: null,
        withContext: true,
      );

      expect(result.success, isFalse);
      expect(result.retries, 1);
      expect(result.isInitialConnection, isTrue);
      verify(() => device.disconnect()).called(1);
      verify(() => device.connect(timeout: any(named: 'timeout'))).called(1);
    });

    test('exhausts all attempts and calls handleError(isInitialConnection: false) on reconnect',
        () async {
      final result = await run(
        maxAttempts: 1,
        isReconnection: true,
        succeedOnAttempt: null,
        withContext: true,
      );

      expect(result.success, isFalse);
      expect(result.isInitialConnection, isFalse);
      verifyNever(() => device.disconnect());
      verifyNever(() => device.connect(timeout: any(named: 'timeout')));
    });

    test('does not call handleError when context is null', () async {
      final result = await run(
        maxAttempts: 2,
        succeedOnAttempt: null,
        withContext: false,
      );

      expect(result.success, isFalse);
      expect(result.isInitialConnection, isNull);
      verify(() => device.disconnect()).called(1);
      verify(() => device.connect(timeout: any(named: 'timeout'))).called(1);
    });

    group('watchForDisconnect', () {
      late StreamController<BluetoothConnectionState> connectionStateController;

      setUp(() {
        manager = BleConnectionManager(
          deviceConnectTimeout: const Duration(milliseconds: 10),
          retryDelay: Duration.zero,
          maxReconnectionAttempts: 2,
        );
        connectionStateController = StreamController.broadcast();
        when(() => device.connectionState)
            .thenAnswer((_) => connectionStateController.stream);
      });

      tearDown(() async {
        manager.cancelReconnection();
        await connectionStateController.close();
      });

      test('calls onStateChange(reconnecting) and onReconnectSuccess on transport disconnect',
          () async {
        final states = <BleConnectionState>[];
        var successCalled = false;

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async => true,
          onReconnectSuccess: () => successCalled = true,
          onStateChange: states.add,
          onPermanentFailure: ({required context, bool isInitialConnection = false}) =>
              fail('permanentFailure should not be called'),
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        connectionStateController.add(BluetoothConnectionState.disconnected);
        await pumpEventQueue();

        expect(states, contains(BleConnectionState.reconnecting));
        expect(successCalled, isTrue);
      });

      test('skips reconnect when shouldSkipReconnect returns true', () async {
        var attemptCount = 0;

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => true,
          attemptReconnection: (_, __) async {
            attemptCount++;
            return true;
          },
          onReconnectSuccess: () => fail('onReconnectSuccess should not be called'),
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {},
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        connectionStateController.add(BluetoothConnectionState.disconnected);
        await pumpEventQueue();

        expect(attemptCount, 0);
      });

      test('ignores a second disconnect emitted while first reconnect is still in progress',
          () async {
        var attemptCount = 0;
        final firstStarted = Completer<void>();
        final firstUnblock = Completer<void>();

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async {
            attemptCount++;
            if (!firstStarted.isCompleted) firstStarted.complete();
            await firstUnblock.future; // keep first reconnect alive
            return true;
          },
          onReconnectSuccess: () {},
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {},
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        // Start the first reconnect and wait until it is actually running.
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await firstStarted.future;
        expect(manager.isInRetryMode, isTrue);

        // Emit a second disconnect while the first reconnect is blocked.
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await pumpEventQueue();

        // Unblock and finish the first reconnect.
        firstUnblock.complete();
        await pumpEventQueue();

        expect(attemptCount, 1);
      });

      test('isInRetryMode is true during reconnect and false after completion', () async {
        final started = Completer<void>();
        final unblock = Completer<void>();

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async {
            if (!started.isCompleted) started.complete();
            await unblock.future;
            return true;
          },
          onReconnectSuccess: () {},
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {},
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        connectionStateController.add(BluetoothConnectionState.disconnected);
        await started.future;

        expect(manager.isInRetryMode, isTrue);

        unblock.complete();
        await pumpEventQueue();

        expect(manager.isInRetryMode, isFalse);
      });

      test('calls onPermanentFailure with isInitialConnection:false after exhausting all attempts',
          () async {
        bool? capturedIsInitialConnection;

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async => false,
          onReconnectSuccess: () => fail('onReconnectSuccess should not be called'),
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {
            capturedIsInitialConnection = isInitialConnection;
          },
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        connectionStateController.add(BluetoothConnectionState.disconnected);
        await pumpEventQueue();

        expect(capturedIsInitialConnection, isFalse);
      });

      test('calls onPermanentFailure when the connection-state stream emits an error',
          () async {
        var permanentFailureCalled = false;

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async => true,
          onReconnectSuccess: () {},
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {
            permanentFailureCalled = true;
          },
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        connectionStateController.addError(Exception('stream error'));
        await pumpEventQueue();

        expect(permanentFailureCalled, isTrue);
      });
    });

    group('cancelReconnection', () {
      test('stops processing further disconnect events after cancellation', () async {
        final connectionStateController =
            StreamController<BluetoothConnectionState>.broadcast();
        when(() => device.connectionState)
            .thenAnswer((_) => connectionStateController.stream);

        var attemptCount = 0;

        manager.watchForDisconnect(
          device,
          shouldSkipReconnect: () => false,
          attemptReconnection: (_, __) async {
            attemptCount++;
            return true;
          },
          onReconnectSuccess: () {},
          onStateChange: (_) {},
          onPermanentFailure: ({required context, bool isInitialConnection = false}) {},
          vibrateOnDisconnect: false,
          context: FakeBuildContext(),
        );

        manager.cancelReconnection();

        connectionStateController.add(BluetoothConnectionState.disconnected);
        await pumpEventQueue();

        expect(attemptCount, 0);
        await connectionStateController.close();
      });

      test('resets isInRetryMode to false', () {
        expect(manager.isInRetryMode, isFalse);
        manager.cancelReconnection();
        expect(manager.isInRetryMode, isFalse);
      });
    });
  });
}
