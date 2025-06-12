import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:flutter/services.dart';
import '../../test_helpers.dart';
import '../../mocks.dart';

void main() {
  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  late Isar isar;
  late TrackService trackService;
  late TrackData trackData;

  setUp(() async {
    initializeTestDependencies();

    // Mock the path_provider plugin
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/mocked_directory';
      }
      return null;
    });

    // Initialize in-memory Isar database
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
      directory: ''
    );

    // Mock IsarProvider to return the in-memory Isar instance
    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    // Initialize TrackService with the mocked IsarProvider
    trackService = TrackService(isarProvider: mockIsarProvider);

    // Clear the database to ensure test isolation
    await isar.writeTxn(() async {
      await isar.trackDatas.clear();
    });

    // Add sample track data to the database
    trackData = TrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });
  });

  tearDown(() async {
    await isar.close();
    channel.setMockMethodCallHandler(null);
  });

  group('TrackService', () {
    group('deleteAllTracks', () {
      test('successfully deletes all tracks from the database', () async {
        final tracksBefore = await isar.trackDatas.where().findAll();
        expect(tracksBefore.length, equals(1));

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });

      test('handles empty database gracefully', () async {
        await trackService.deleteAllTracks();

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });

      test('deletes multiple tracks from the database', () async {
        final trackData2 = TrackData();
        await isar.writeTxn(() async {
          await isar.trackDatas.put(trackData2);
        });

        final tracksBefore = await isar.trackDatas.where().findAll();
        expect(tracksBefore.length, equals(2));

        await trackService.deleteAllTracks();

        final tracksAfter = await isar.trackDatas.where().findAll();
        expect(tracksAfter.isEmpty, isTrue);
      });
    });
  });
}