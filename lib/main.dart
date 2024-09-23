import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
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
  const SenseBoxBikeApp({Key? key}) : super(key: key);

  @override
  _SenseBoxBikeAppState createState() => _SenseBoxBikeAppState();
}

class _SenseBoxBikeAppState extends State<SenseBoxBikeApp> {
  static const List<Widget> _pages = <Widget>[HomeScreen(), TracksScreen()];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isarService = IsarService();
    final bleBloc = BleBloc();
    final trackBloc = TrackBloc(isarService);
    final OpenSenseMapBloc openSenseMapBloc = OpenSenseMapBloc();
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
            brightness: platformBrightness == Brightness.light
                ? Brightness.light
                : Brightness.dark,
            canvasColor: platformBrightness == Brightness.light
                ? Colors.grey[200]
                : Colors.grey[900],
            colorSchemeSeed: Colors.teal,
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
                      topRight: Radius.circular(16),
                      topLeft: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black38, spreadRadius: 0, blurRadius: 4),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: BottomNavigationBar(
                    selectedFontSize: 0,
                    onTap: (value) {
                      setState(() {
                        _selectedIndex = value;
                      });
                    },
                    currentIndex: _selectedIndex,
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(icon: Icon(Icons.map), label: ""),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.route), label: "")
                    ],
                  ),
                ),
              ))),
    );
  }
}
