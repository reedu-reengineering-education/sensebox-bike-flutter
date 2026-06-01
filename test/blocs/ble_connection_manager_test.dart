import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/ble_connection_manager.dart';
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
  });
}
