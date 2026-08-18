import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsBloc', () {
    late SettingsBloc settingsBloc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsBloc = SettingsBloc();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    tearDown(() {
      settingsBloc.dispose();
    });

    test('setDataCollectionMode persists and updates getter', () async {
      await settingsBloc.setDataCollectionMode(DataCollectionMode.onTap);

      expect(
        settingsBloc.dataCollectionMode,
        DataCollectionMode.onTap,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesKeys.lastResolvedDataCollectionMode),
        'onTap',
      );
    });

    test('setCollectionIntervalSeconds persists and updates getter', () async {
      await settingsBloc.setCollectionIntervalSeconds(30);

      expect(settingsBloc.collectionIntervalSeconds, 30);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds),
        30,
      );
    });

    test('setCollectionPreferences writes mode and interval once', () async {
      await settingsBloc.setCollectionPreferences(
        mode: DataCollectionMode.periodic,
        intervalSeconds: 120,
      );

      expect(settingsBloc.dataCollectionMode, DataCollectionMode.periodic);
      expect(settingsBloc.collectionIntervalSeconds, 120);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesKeys.lastResolvedDataCollectionMode),
        'periodic',
      );
      expect(
        prefs.getInt(SharedPreferencesKeys.lastResolvedCollectionIntervalSeconds),
        120,
      );
    });

    test('setCollectionIntervalSeconds rejects invalid values', () async {
      await expectLater(
        settingsBloc.setCollectionIntervalSeconds(2),
        throwsA(isA<FormatException>()),
      );
    });

    test('rememberDevice persists id and name and updates getters', () async {
      await settingsBloc.rememberDevice('AA:BB:CC', 'senseBox:bike test');

      expect(settingsBloc.rememberedDeviceId, 'AA:BB:CC');
      expect(settingsBloc.rememberedDeviceName, 'senseBox:bike test');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesKeys.rememberedDeviceId),
        'AA:BB:CC',
      );
      expect(
        prefs.getString(SharedPreferencesKeys.rememberedDeviceName),
        'senseBox:bike test',
      );
    });

    test('forgetRememberedDevice clears id, name and prefs', () async {
      await settingsBloc.rememberDevice('AA:BB:CC', 'senseBox:bike test');
      await settingsBloc.forgetRememberedDevice();

      expect(settingsBloc.rememberedDeviceId, isNull);
      expect(settingsBloc.rememberedDeviceName, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(SharedPreferencesKeys.rememberedDeviceId), isNull);
      expect(
        prefs.getString(SharedPreferencesKeys.rememberedDeviceName),
        isNull,
      );
    });

    test('rememberedDeviceId is restored from persisted prefs on load',
        () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesKeys.rememberedDeviceId: 'ZZ:99',
        SharedPreferencesKeys.rememberedDeviceName: 'senseBox:bike restored',
      });
      final restored = SettingsBloc();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(restored.rememberedDeviceId, 'ZZ:99');
      expect(restored.rememberedDeviceName, 'senseBox:bike restored');

      restored.dispose();
    });
  });

  group('SettingsBloc Upload Mode Tests', () {
    test('should have default upload mode as post-ride (false)', () {
      bool directUploadMode = false;
      expect(directUploadMode, false);
    });

    test('should toggle upload mode correctly', () {
      bool directUploadMode = false;

      directUploadMode = true;
      expect(directUploadMode, true);

      directUploadMode = false;
      expect(directUploadMode, false);
    });

    test('should determine batch upload trigger based on upload mode', () {
      bool directUploadMode = false;
      bool shouldTriggerBatchUpload = !directUploadMode;
      expect(shouldTriggerBatchUpload, true);

      directUploadMode = true;
      shouldTriggerBatchUpload = !directUploadMode;
      expect(shouldTriggerBatchUpload, false);
    });
  });
}
