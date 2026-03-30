import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/app/app_bloc_observer.dart';
import 'package:sensebox_bike/app/app_dependencies.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/secrets.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();
  await dotenv.load(fileName: '.env', mergeWith: Platform.environment);
  final dependencies = await AppDependencies.create();

  await SentryFlutter.init(
    (options) => options
      ..dsn = sentryDsn
      ..sampleRate = 1.0
      ..debug = false
      ..diagnosticLevel = SentryLevel.warning
      ..sendDefaultPii = false,
    appRunner: () => runApp(
      SentryWidget(
        child: SenseBoxBikeApp(dependencies: dependencies),
      ),
    ),
  );
}

class SenseBoxBikeApp extends StatefulWidget {
  const SenseBoxBikeApp({
    required this.dependencies,
    super.key,
  });

  final AppDependencies dependencies;

  @override
  State<SenseBoxBikeApp> createState() => _SenseBoxBikeAppState();
}

class _SenseBoxBikeAppState extends State<SenseBoxBikeApp>
    with WidgetsBindingObserver {
  late final StreamSubscription<Uri> _appLinksSubscription;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = createAppRouter(isarService: widget.dependencies.isarService);
    _initErrorHandlers();
    widget.dependencies.openSenseMapBloc.performAuthenticationCheck();
    _appLinksSubscription = AppLinks().uriLinkStream.listen(_handleIncomingUri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.dependencies.openSenseMapBloc.performAuthenticationCheck();
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    final action = uri.host;
    if (action != 'start') {
      return;
    }

    final id = uri.queryParameters['id'];
    if (id == null) {
      debugPrint('No device id provided in app link');
      return;
    }

    final fullId = 'senseBox:bike [$id]';
    await widget.dependencies.bleBloc.connectToId(fullId, context);
    await Future<void>.delayed(const Duration(seconds: 2));
    await widget.dependencies.recordingBloc.startRecording();
  }

  void _initErrorHandlers() {
    FlutterError.onError = (details) {
      Sentry.captureException(details.exception, stackTrace: details.stack);

      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorService.handleError(
          details.exception,
          details.stack ?? StackTrace.empty,
          sendToSentry: true,
        );
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appLinksSubscription.cancel();
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );

    return MultiProvider(
      providers: [
        BlocProvider.value(value: widget.dependencies.settingsBloc),
        BlocProvider.value(value: widget.dependencies.trackBloc),
        BlocProvider.value(value: widget.dependencies.recordingBloc),
        BlocProvider.value(value: widget.dependencies.bleBloc),
        BlocProvider.value(value: widget.dependencies.geolocationBloc),
        BlocProvider.value(value: widget.dependencies.sensorBloc),
        BlocProvider.value(value: widget.dependencies.openSenseMapBloc),
        Provider.value(value: widget.dependencies.configurationBloc),
        Provider<OpenSenseMapService>.value(
          value: widget.dependencies.openSenseMapService,
        ),
        ChangeNotifierProvider.value(
          value: widget.dependencies.mapboxDrawController,
        ),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: ErrorService.scaffoldKey,
        title: 'senseBox:bike',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: lightTheme,
        darkTheme: darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
