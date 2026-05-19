import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import '../mocks.dart';

void _mockMapboxAccessTokenChannel() {
  const codec = StandardMessageCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.mapbox_maps_flutter._MapboxOptions.setAccessToken',
    (ByteData? message) async =>
        codec.encodeMessage(<Object?>[]),
  );
}

void main() {
  late MockBleBloc mockBleBloc;
  late MockGeolocationBloc mockGeolocationBloc;
  late MockRecordingBloc mockRecordingBloc;
  late MockIsarService mockIsarService;
  Future<void> Function()? onRecordingStart;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _mockMapboxAccessTokenChannel();
    dotenv.testLoad(
      fileInput: 'MAPBOX_ACCESS_TOKEN=test\nENABLE_SENSOR_CSV_LOGGING=false\n',
    );
  });

  test('onRecordingStart emits current location without starting geo listener',
      () async {
    mockBleBloc = MockBleBloc();
    mockGeolocationBloc = MockGeolocationBloc();
    mockRecordingBloc = MockRecordingBloc();
    mockIsarService = MockIsarService();

    when(() => mockGeolocationBloc.isarService).thenReturn(mockIsarService);
    when(() => mockGeolocationBloc.startListening()).thenAnswer((_) async {});
    when(() => mockGeolocationBloc.getCurrentLocationAndEmit())
        .thenAnswer((_) async {});
    when(() => mockRecordingBloc.directUploadService).thenReturn(null);
    when(
      () => mockRecordingBloc.setRecordingCallbacks(
        onRecordingStart: any(named: 'onRecordingStart'),
        onRecordingStop: any(named: 'onRecordingStop'),
      ),
    ).thenAnswer((invocation) {
      onRecordingStart = invocation.namedArguments[#onRecordingStart]
          as Future<void> Function()?;
    });

    final sensorBloc = SensorBloc(
      mockBleBloc,
      mockGeolocationBloc,
      mockRecordingBloc,
    );
    await Future<void>.delayed(Duration.zero);
    addTearDown(() {
      mockBleBloc.dispose();
      sensorBloc.dispose();
    });

    expect(onRecordingStart, isNotNull);

    await onRecordingStart!();

    verifyNever(() => mockGeolocationBloc.startListening());
    verify(() => mockGeolocationBloc.getCurrentLocationAndEmit()).called(1);
  });
}
