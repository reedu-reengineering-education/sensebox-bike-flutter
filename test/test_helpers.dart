import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:isar_community/isar.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initializes common test dependencies
void initializeTestDependencies() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock SharedPreferences
  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    },
  );

  // Ensure SharedPreferences is initialized
  SharedPreferences.setMockInitialValues({});
}

/// Creates a MaterialApp wrapper with localization support
Widget createLocalizedTestApp({
  required Widget child,
  required Locale locale,
  List<LocalizationsDelegate<dynamic>>? additionalDelegates,
}) {
  return MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      ...?additionalDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: child,
  );
}

/// Disables Provider debug checks
void disableProviderDebugChecks() {
  Provider.debugCheckInvalidValueType = null;
}

Future<void> tapElement(
    FinderBase<Element> element, WidgetTester tester) async {
  await tester.tap(element);
  await tester.pumpAndSettle();
}

Future<Isar> initializeInMemoryIsar() async {
  await Isar.initializeIsarCore(download: true);
  return await Isar.open(
    [TrackDataSchema, GeolocationDataSchema, SensorDataSchema],
    directory: '',
  );
}

void mockPathProvider(String tempDirectoryPath) {
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  pathProviderChannel.setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return tempDirectoryPath;
    }
    return null;
  });
}

Future<void> clearIsarDatabase(Isar isar) async {
  await isar.writeTxn(() async {
    await isar.trackDatas.clear();
    await isar.geolocationDatas.clear();
    await isar.sensorDatas.clear();
  });
}

void mockSenseBoxInSharedPreferences() {
  final senseBox = SenseBox(
    name: 'Test SenseBox',
    grouptag: ['Sensor Group'],
    sensors: [
      Sensor(
        id: 'test-temp-sensor',
        title: 'Temperature',
        unit: '°C',
        sensorType: 'HDC1080',
        icon: 'osem-thermometer',
      ),
      Sensor(
        id: 'test-speed-sensor',
        title: 'Speed',
        unit: 'm/s',
        sensorType: 'GPS',
        icon: 'osem-dashboard',
      ),
    ],
  );

  SharedPreferences.setMockInitialValues(
    {'selectedSenseBox': jsonEncode(senseBox.toJson())},
  );
}

TrackData createMockTrackData() {
  return TrackData()
    ..id = Isar.autoIncrement;
}

GeolocationData createMockGeolocationData(TrackData trackData) {
  return GeolocationData()
    ..id = Isar.autoIncrement
    ..latitude = 52.5200
    ..longitude = 13.4050
    ..timestamp = DateTime.now()
    ..speed = 0.0
    ..track.value = trackData;
}

/// Creates a simple GeolocationData for coordinate testing
GeolocationData createTestGeolocation(double latitude, double longitude) {
  return GeolocationData()
    ..latitude = latitude
    ..longitude = longitude
    ..timestamp = DateTime.now()
    ..speed = 0.0;
}

SensorData createMockSensorData(GeolocationData geolocationData) {
  return SensorData()
    ..id = Isar.autoIncrement
    ..title = 'temperature'
    ..value = 25.0
    ..attribute = null
    ..characteristicUuid = '1234-5678-9012-3456'
    ..geolocationData.value = geolocationData;
}
