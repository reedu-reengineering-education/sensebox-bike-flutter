import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String mapboxAccessToken = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: "");

final Guid senseBoxServiceUUID =
    Guid.fromString('CF06A218-F68E-E0BE-AD04-8EBC1EB0BC84');

final Guid deviceInfoServiceUUID =
    Guid.fromString('CF06A218-F68E-E0BE-AD04-8EBC1EB0BC85');

String sentryDsn = dotenv.get('SENTRY_DSN', fallback: "");
