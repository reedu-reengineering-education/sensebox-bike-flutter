import 'package:flutter_dotenv/flutter_dotenv.dart';

String mapboxAccessToken = dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: "");

String sentryDsn = dotenv.get('SENTRY_DSN', fallback: "");
