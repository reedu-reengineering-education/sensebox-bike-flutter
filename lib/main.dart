import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'ui/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'blocs/ble_bloc.dart';
import 'blocs/geolocation_bloc.dart';

void main() async {
  await dotenv.load(fileName: ".env", mergeWith: Platform.environment);

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
    },
    appRunner: () => runApp(const MyApp()),
  );
  // runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isarService = IsarService();
    final bleBloc = BleBloc();
    final trackBloc = TrackBloc(isarService);
    final OpenSenseMapBloc openSenseMapBloc = OpenSenseMapBloc();
    final recordingBloc =
        RecordingBloc(isarService, bleBloc, trackBloc, openSenseMapBloc);
    final geolocationBloc = GeolocationBloc(isarService, recordingBloc);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => trackBloc),
        ChangeNotifierProvider(
            create: (_) => recordingBloc), // Initialize first
        ChangeNotifierProvider(create: (_) => bleBloc),
        ChangeNotifierProvider(create: (_) => geolocationBloc),
        ChangeNotifierProvider(
            create: (_) => SensorBloc(bleBloc, geolocationBloc)),
        ChangeNotifierProvider(create: (_) => openSenseMapBloc),
      ],
      child: MaterialApp(
        title: 'senseBox:bike',
        theme: ThemeData(
          textTheme: GoogleFonts.syneTextTheme(),
          colorSchemeSeed: Colors.teal,
          cardTheme: CardTheme(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
