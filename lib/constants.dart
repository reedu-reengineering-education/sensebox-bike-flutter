import 'package:geolocator/geolocator.dart' as geolocator;

// Tracks screen
const tracksPerPage = 5;

// LiveUploadService
const maxRetries = 10;
const retryPeriod = 2; // in minutes
const premanentConnectivityFalurePeriod = 10; // in minutes
const defaultTimeout = 30; // in seconds

class SharedPreferencesKeys {
  static const String privacyPolicyAcceptedAt = 'privacyPolicyAcceptedAt';
  static const String privacyZones = 'privacyZones';
  static const String selectedSenseBox = 'selectedSenseBox';
  static const bool vibrateOnDisconnect = false;
}

const openSenseMapUrl = 'https://api.opensensemap.org';
const openSenseMapWebsiteUrl = 'https://opensensemap.org/';
const senseBoxBikePrivacyPolicyUrl =
    'https://sensebox.de/sensebox-bike-privacy-policy';
const contactEmail = 'kontakt@reedu.de';
const gitHubNewIssueUrl =
    'https://github.com/reedu-reengineering-education/sensebox-bike-flutter/issues/new/choose';
const privacyPolicyUrl =
    'https://opensensemap.org/privacy';
const knowledgeBaseUrl =
    'https://docs.sensebox.de/docs/products/bike/app/download/';
const githubDataBaseUrl =
    'https://raw.githubusercontent.com/reedu-reengineering-education/sensebox-bike-flutter/main/data';
const campaignsPath = '/locations.json';
const boxConfigurationsPath = '/box_configurations.json';

const campaignsUrl = '$githubDataBaseUrl$campaignsPath';
const boxConfigurationsUrl = '$githubDataBaseUrl$boxConfigurationsPath';

final globePosition = geolocator.Position(
    latitude: 0.0,
    longitude: 0.0,
    timestamp: DateTime(2000),
    accuracy: 0.0,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0);

const defaultCameraOptions = {
  "zoom": 16.0,
  "pitch": 45.0,
};

/// The canonical order of sensors for display and sorting throughout the app.
const List<String> sensorOrder = [
  'temperature',
  'humidity',
  'distance',
  'overtaking',
  'surface_classification_asphalt',
  'surface_classification_compacted',
  'surface_classification_paving',
  'surface_classification_sett',
  'surface_classification_standing',
  'surface_anomaly',
  'acceleration_x',
  'acceleration_y',
  'acceleration_z',
  'finedust_pm1',
  'finedust_pm2.5',
  'finedust_pm4',
  'finedust_pm10',
  'gps_latitude',
  'gps_longitude',
  'gps_speed',
];
