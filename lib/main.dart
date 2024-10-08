import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
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
    appRunner: () => runApp(const SenseBoxBikeApp()),
  );
  // runApp(const MyApp());
}

class SenseBoxBikeApp extends StatefulWidget {
  const SenseBoxBikeApp({super.key});

  @override
  _SenseBoxBikeAppState createState() => _SenseBoxBikeAppState();
}

class _SenseBoxBikeAppState extends State<SenseBoxBikeApp> {
  static final List<Widget> _pages = <Widget>[
    const PopScope(
      canPop: false,
      child: HomeScreen(),
    ),
    const PopScope(
      canPop: false,
      child: TracksScreen(),
    ),
    const PopScope(
      canPop: false,
      child: SettingsScreen(),
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isarService = IsarService();
    final settingsBloc = SettingsBloc();
    final bleBloc = BleBloc(settingsBloc);
    final OpenSenseMapBloc openSenseMapBloc = OpenSenseMapBloc();
    final trackBloc = TrackBloc(isarService);
    final recordingBloc =
        RecordingBloc(isarService, bleBloc, trackBloc, openSenseMapBloc);
    final geolocationBloc = GeolocationBloc(isarService, recordingBloc);

    final Brightness platformBrightness =
        MediaQuery.platformBrightnessOf(context);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarBrightness: platformBrightness == Brightness.light
          ? Brightness.light
          : Brightness.dark,
    ));

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsBloc),
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
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey[50], // Light background color
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            colorScheme: const ColorScheme.light(
                primary: Colors.black, secondary: Colors.black12),
            canvasColor: Colors.grey[50],
            cardTheme: CardTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          darkTheme: ThemeData(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color.fromARGB(
                  255, 24, 24, 24), // Light background color
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            canvasColor: const Color.fromARGB(255, 24, 24, 24),
            colorScheme: const ColorScheme.dark(
                primary: Colors.white,
                secondary: Colors.white,
                surface: Color(0xFF121212)),
            cardTheme: CardTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          home: Scaffold(
              body: _pages.elementAt(_selectedIndex),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      topLeft: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black38, spreadRadius: 0, blurRadius: 12),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: NavigationBar(
                    onDestinationSelected: (value) {
                      setState(() {
                        _selectedIndex = value;
                      });
                    },
                    selectedIndex: _selectedIndex,
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.map), label: 'Home'),
                      NavigationDestination(
                          icon: Icon(Icons.route), label: 'Tracks'),
                      NavigationDestination(
                          icon: Icon(Icons.settings), label: 'Settings')
                    ],
                  ),
                ),
              ))),
    );
  }
}
