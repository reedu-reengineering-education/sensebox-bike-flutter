import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  await dotenv.load(fileName: ".env", mergeWith: Platform.environment);

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
      options.profilesSampleRate = 1.0;
    },
    //appRunner: () => runApp(const SenseBoxBikeApp()),
    appRunner: () => runZonedGuarded(() {
      WidgetsFlutterBinding.ensureInitialized();
      // Error handlers
      FlutterError.onError = (details) {
        if (!kDebugMode) {
          Sentry.captureException(details.exception, stackTrace: details.stack);
        }
        ErrorService.handleError(details.exception, details.stack!);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kDebugMode) {
          Sentry.captureException(error, stackTrace: stack);
        }
        ErrorService.handleError(error, stack);
        return true;
      };

      runApp(const SenseBoxBikeApp());
    }, (error, stack) {
      if (!kDebugMode) {
        Sentry.captureException(error, stackTrace: stack);
      }
      ErrorService.handleError(error, stack);
    }),
  );
}

class SenseBoxBikeApp extends StatelessWidget {
  const SenseBoxBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appLinks = AppLinks();

    // Initialize providers at the top level
    final settingsBloc = SettingsBloc();
    final isarService = IsarService();
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
        home: const AppHome(),
      ),
    );
  }
}
