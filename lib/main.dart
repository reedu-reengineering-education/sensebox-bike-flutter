import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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

class SenseBoxBikeApp extends StatefulWidget {
  const SenseBoxBikeApp({super.key});

  @override
  State<SenseBoxBikeApp> createState() => _SenseBoxBikeAppState();
}

class _SenseBoxBikeAppState extends State<SenseBoxBikeApp> {
  // Store blocs as static fields to ensure they're created only once
  static SettingsBloc? _settingsBloc;
  static IsarService? _isarService;
  static BleBloc? _bleBloc;
  static OpenSenseMapBloc? _openSenseMapBloc;
  static TrackBloc? _trackBloc;
  static RecordingBloc? _recordingBloc;
  static GeolocationBloc? _geolocationBloc;
  static SensorBloc? _sensorBloc;
  static MapboxDrawController? _mapboxDrawController;
  static StreamSubscription<Uri>? _appLinksSubscription;
  static bool _isInitialized = false;

  // Initialize all blocs and services once
  static void _initializeBlocs() {
    if (_isInitialized) return; // Already initialized

    _settingsBloc = SettingsBloc();
    _isarService = IsarService(isarProvider: IsarProvider());
    _bleBloc = BleBloc(_settingsBloc!);
    _openSenseMapBloc = OpenSenseMapBloc();
    _trackBloc = TrackBloc(_isarService!);
    _recordingBloc = RecordingBloc(_isarService!, _bleBloc!, _trackBloc!,
        _openSenseMapBloc!, _settingsBloc!);
    _geolocationBloc =
        GeolocationBloc(_isarService!, _recordingBloc!, _settingsBloc!);
    _sensorBloc = SensorBloc(
        _bleBloc!, _geolocationBloc!, _recordingBloc!, _settingsBloc!);
    _mapboxDrawController = MapboxDrawController();

    _isInitialized = true;
    debugPrint('Blocs initialized successfully');
  }

  @override
  void initState() {
    super.initState();

    // Initialize blocs if they haven't been initialized yet
    if (!_isInitialized) {
      _initializeBlocs();
    }

    // Handle app links only once
    if (_appLinksSubscription == null) {
      final appLinks = AppLinks();
      _appLinksSubscription = appLinks.uriLinkStream.listen((uri) async {
        debugPrint('Received uri: $uri');
        String action = uri.host;
        if (action == "start") {
          debugPrint('Connecting to device and starting recording');
          final id = uri.queryParameters['id'];
          if (id == null) {
            debugPrint('No id provided');
            return;
          }

          final fullId = "senseBox:bike [$id]";
          debugPrint('Connecting to $fullId');
          await _bleBloc!.connectToId(fullId, context);
          await Future.delayed(const Duration(seconds: 2));
          _recordingBloc!.startRecording();
        }
      });
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _appLinksSubscription?.cancel();
    super.dispose();
  }

  void _initErrorHandlers() {
    FlutterError.onError = (details) {
      Sentry.captureException(details.exception, stackTrace: details.stack);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorService.handleError(
            details.exception, details.stack ?? StackTrace.empty,
            sendToSentry: true);
      });
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Sentry.captureException(error, stackTrace: stack);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorService.handleError(error, stack, sendToSentry: true);
      });
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    _initErrorHandlers();
    
    // Manipulations below are to make sure default Android status bar is visible
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent status bar
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness
                .dark, // Light icons for dark mode, dark icons for light mode
        statusBarBrightness: isDarkMode
            ? Brightness.dark
            : Brightness.light, // For iOS compatibility
      ),
    );
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _settingsBloc!),
        ChangeNotifierProvider.value(value: _trackBloc!),
        ChangeNotifierProvider.value(value: _recordingBloc!),
        ChangeNotifierProvider.value(value: _bleBloc!),
        ChangeNotifierProvider.value(value: _geolocationBloc!),
        ChangeNotifierProvider.value(value: _sensorBloc!),
        ChangeNotifierProvider.value(value: _openSenseMapBloc!),
        ChangeNotifierProvider.value(value: _mapboxDrawController!),
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
