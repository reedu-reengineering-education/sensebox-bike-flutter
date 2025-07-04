import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter_draw/mapbox_maps_flutter_draw.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/initial_screen.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env", mergeWith: Platform.environment);

  await SentryFlutter.init(
    (options) => options
      ..dsn = sentryDsn
      ..sampleRate = 1.0
      // Disable sending request headers and IP for users
      ..sendDefaultPii = false,
    appRunner: () => runApp(SentryWidget(child: SenseBoxBikeApp())),
  );
}

class SenseBoxBikeApp extends StatelessWidget {
  const SenseBoxBikeApp({super.key});

  void _initErrorHandlers() {
    FlutterError.onError = (details) {
      Sentry.captureException(details.exception, stackTrace: details.stack);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorService.handleError(
            details.exception, details.stack ?? StackTrace.empty,
            sendToSentry: false);
      });
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Sentry.captureException(error, stackTrace: stack);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorService.handleError(error, stack, sendToSentry: false);
      });
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    _initErrorHandlers();

    final appLinks = AppLinks();
    // Initialize providers at the top level
    final settingsBloc = SettingsBloc();
    final isarService = IsarService(isarProvider: IsarProvider());
    final bleBloc = BleBloc(settingsBloc);
    final openSenseMapBloc = OpenSenseMapBloc();
    final trackBloc = TrackBloc(isarService);
    final recordingBloc = RecordingBloc(
        isarService, bleBloc, trackBloc, openSenseMapBloc, settingsBloc);
    final geolocationBloc =
        GeolocationBloc(isarService, recordingBloc, settingsBloc);
    final sensorBloc = SensorBloc(bleBloc, geolocationBloc);
    final MapboxDrawController mapboxDrawController = MapboxDrawController();

    // Subscribe to all events (initial link and further)
    final sub = appLinks.uriLinkStream.listen((uri) async {
      print('Received uri: $uri');
      String action = uri.host;
      if (action == "start") {
        print('Connecting to device and starting recording');
        final id = uri.queryParameters['id'];
        if (id == null) {
          print('No id provided');
          return;
        }

        final fullId = "senseBox:bike [$id]";
        print('Connecting to $fullId');
        await bleBloc.connectToId(fullId, context);
        await Future.delayed(const Duration(seconds: 2));
        recordingBloc.startRecording();
      }
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsBloc),
        ChangeNotifierProvider(create: (_) => trackBloc),
        ChangeNotifierProvider(create: (_) => recordingBloc),
        ChangeNotifierProvider(create: (_) => bleBloc),
        ChangeNotifierProvider(create: (_) => geolocationBloc),
        ChangeNotifierProvider(create: (_) => sensorBloc),
        ChangeNotifierProvider(create: (_) => openSenseMapBloc),
        ChangeNotifierProvider(create: (_) => mapboxDrawController),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: ErrorService.scaffoldKey,
        title: 'senseBox:bike',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: const InitialScreen(),
      ),
    );
  }
}
