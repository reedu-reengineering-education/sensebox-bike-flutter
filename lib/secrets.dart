import 'package:flutter_dotenv/flutter_dotenv.dart';

String mapboxAccessToken = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: "");

const String senseBoxServiceUUID = 'CF06A218-F68E-E0BE-AD04-8EBC1EB0BC84';

const String deviceInfoServiceUUID = 'CF06A218-F68E-E0BE-AD04-8EBC1EB0BC85';

String sentryDsn = dotenv.get('SENTRY_DSN', fallback: "");
