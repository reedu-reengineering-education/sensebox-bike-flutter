import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import '../../mocks.dart';
import '../../test_helpers.dart';

void main() {
  late Isar isar;
  late GeolocationService geolocationService;
  late GeolocationData geolocationData;

  setUp(() async {
    initializeTestDependencies();

    // Initialize in-memory Isar database
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
      directory: ''
    );

    final mockIsarProvider = MockIsarProvider();
    when(() => mockIsarProvider.getDatabase()).thenAnswer((_) async => isar);

    geolocationService = GeolocationService(isarProvider: mockIsarProvider);

    // Add sample geolocation data to the database
    geolocationData = GeolocationData()
      ..latitude = 52.5200
      ..longitude = 13.4050
      ..timestamp = DateTime.now().toUtc()
      ..speed = 0.0;

    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData);
    });
  });

  tearDown(() async {
    await isar.close();
  });

group('deleteAllGeolocations', () {
  test('successfully deletes all geolocations from the database', () async {
    // Verify that the geolocation data exists before deletion
    final geolocationsBefore = await isar.geolocationDatas.where().findAll();
    expect(geolocationsBefore.length, equals(1));

    await geolocationService.deleteAllGeolocations();

    final geolocationsAfter = await isar.geolocationDatas.where().findAll();
    expect(geolocationsAfter.isEmpty, isTrue);
  });

  test('handles empty database gracefully', () async {
    await geolocationService.deleteAllGeolocations();

    final geolocationsAfter = await isar.geolocationDatas.where().findAll();
    expect(geolocationsAfter.isEmpty, isTrue);
  });

  test('deletes multiple geolocations from the database', () async {
    // Arrange: Add multiple geolocation records
    final geolocationData2 = GeolocationData()
      ..latitude = 48.8566
      ..longitude = 2.3522
      ..timestamp = DateTime.now().toUtc()
      ..speed = 10.0;

    await isar.writeTxn(() async {
      await isar.geolocationDatas.put(geolocationData2);
    });

    // Verify that multiple geolocation records exist before deletion
    final geolocationsBefore = await isar.geolocationDatas.where().findAll();
    expect(geolocationsBefore.length, equals(2));

    await geolocationService.deleteAllGeolocations();

    final geolocationsAfter = await isar.geolocationDatas.where().findAll();
    expect(geolocationsAfter.isEmpty, isTrue);
  });

  test('throws exception if database operation fails', () async {
    await isar.close(); // Close the database to simulate failure

    expect(
      () async => await geolocationService.deleteAllGeolocations(),
      throwsA(isA<Exception>()),
    );
  });
});
}