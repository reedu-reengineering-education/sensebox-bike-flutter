import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter_draw/mapbox_maps_flutter_draw.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/sensor_csv_logger_service.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';
import 'package:sensebox_bike/services/storage/settings_storage.dart';

class AppDependencies {
  AppDependencies({
    required this.settingsBloc,
    required this.isarService,
    required this.bleBloc,
    required this.configurationBloc,
    required this.openSenseMapBloc,
    required this.openSenseMapService,
    required this.trackBloc,
    required this.recordingBloc,
    required this.geolocationBloc,
    required this.sensorBloc,
    required this.mapboxDrawController,
  });

  final SettingsBloc settingsBloc;
  final IsarService isarService;
  final BleBloc bleBloc;
  final ConfigurationBloc configurationBloc;
  final OpenSenseMapBloc openSenseMapBloc;
  final OpenSenseMapService openSenseMapService;
  final TrackBloc trackBloc;
  final RecordingBloc recordingBloc;
  final GeolocationBloc geolocationBloc;
  final SensorBloc sensorBloc;
  final MapboxDrawController mapboxDrawController;

  static Future<AppDependencies> create() async {
    final prefs = SharedPreferences.getInstance();
    final settingsBloc = SettingsBloc(
      storage: SharedPreferencesSettingsStorage(prefs: prefs),
    );
    final isarService = IsarService(isarProvider: IsarProvider());
    final bleBloc = BleBloc(settingsBloc);
    final configurationBloc = ConfigurationBloc();
    final openSenseMapService = OpenSenseMapService(prefs: prefs);
    final openSenseMapBloc = OpenSenseMapBloc(
      configurationBloc: configurationBloc,
      service: openSenseMapService,
      selectedSenseBoxStorage:
          SharedPreferencesSelectedSenseBoxStorage(prefs: prefs),
    );
    final trackBloc = TrackBloc(isarService);
    final recordingBloc = RecordingBloc(
      isarService,
      bleBloc,
      trackBloc,
      openSenseMapBloc,
      settingsBloc,
      openSenseMapService: openSenseMapService,
    );
    final geolocationBloc =
        GeolocationBloc(isarService, recordingBloc, settingsBloc);
    final sensorBloc =
        SensorBloc(bleBloc, geolocationBloc, recordingBloc, settingsBloc);
    final mapboxDrawController = MapboxDrawController();

    configurationBloc.loadAll().catchError((Object error) {
      debugPrint('Failed to preload configurations: $error');
    });

    if (!kReleaseMode) {
      final enableLogging = dotenv
              .get('ENABLE_SENSOR_CSV_LOGGING', fallback: 'false')
              .toLowerCase() ==
          'true';
      if (enableLogging) {
        final csvLogger = SensorCsvLoggerService();
        await csvLogger.initialize();
      }
    }

    return AppDependencies(
      settingsBloc: settingsBloc,
      isarService: isarService,
      bleBloc: bleBloc,
      configurationBloc: configurationBloc,
      openSenseMapBloc: openSenseMapBloc,
      openSenseMapService: openSenseMapService,
      trackBloc: trackBloc,
      recordingBloc: recordingBloc,
      geolocationBloc: geolocationBloc,
      sensorBloc: sensorBloc,
      mapboxDrawController: mapboxDrawController,
    );
  }

  void dispose() {
    unawaited(sensorBloc.close());
    unawaited(geolocationBloc.close());
    unawaited(recordingBloc.close());
    unawaited(trackBloc.close());
    unawaited(openSenseMapBloc.close());
    unawaited(bleBloc.close());
    settingsBloc.dispose();
  }
}
