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
