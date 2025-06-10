import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

void main() {
  late Isar isar;
  late TrackData trackData;

  setUp(() async {
    // Initialize in-memory Isar database
    await Isar.initializeIsarCore(download: true);
    isar = await Isar.open(
      [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
      directory: ''
    );

    // Create a new TrackData instance
    trackData = TrackData();
    await isar.writeTxn(() async {
      await isar.trackDatas.put(trackData);
    });
  });

  tearDown(() async {
    // Close the Isar database
    await isar.close();
  });

  test('encodedPolyline returns empty string for empty geolocations', () async {
    expect(trackData.encodedPolyline, equals(""));
  });

  test('encodedPolyline handles single point correctly', () async {
    // Add a single geolocation to the track
    final geolocation = GeolocationData()
      ..latitude = 52.5200
      ..longitude = 13.4050
      ..timestamp = DateTime.now().toUtc()
      ..speed = 0.0;

    await isar.writeTxn(() async {
      trackData.geolocations.add(geolocation);
      await isar.geolocationDatas.put(geolocation);
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline contains two points (single point + offset)
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, equals(2));
  });

  test('encodedPolyline handles short tracks without simplification', () async {
    // Add fewer than 10 geolocations
    await isar.writeTxn(() async {
      for (int i = 0; i < 5; i++) {
        final geolocation = GeolocationData()
          ..latitude = 52.5200 + i * 0.001
          ..longitude = 13.4050 + i * 0.001
          ..timestamp = DateTime.now().toUtc().add(Duration(seconds: i))
          ..speed = 0.0;
        trackData.geolocations.add(geolocation);
        await isar.geolocationDatas.put(geolocation);
      }
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline contains all points
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, equals(5));
  });

  test('encodedPolyline simplifies long tracks dynamically', () async {
    // Add more than 10 geolocations
    await isar.writeTxn(() async {
      for (int i = 0; i < 20; i++) {
        final geolocation = GeolocationData()
          ..latitude = 52.5200 + i * 0.001
          ..longitude = 13.4050 + i * 0.001
          ..timestamp = DateTime.now().toUtc().add(Duration(seconds: i))
          ..speed = 0.0;
        trackData.geolocations.add(geolocation);
        await isar.geolocationDatas.put(geolocation);
      }
    });

    final polyline = trackData.encodedPolyline;
    expect(polyline.isNotEmpty, isTrue);

    // Verify that the polyline is simplified
    final decodedPolyline = decodePolyline(polyline);
    expect(decodedPolyline.length, lessThan(20));
  });

  test('calculateTolerance scales dynamically with number of coordinates', () {
    final toleranceSmall = trackData.calculateTolerance(10);
    final toleranceLarge = trackData.calculateTolerance(1000);

    expect(toleranceSmall, lessThan(toleranceLarge));
  });
}