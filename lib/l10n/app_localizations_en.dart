// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get generalLoading => 'Loading...';

  @override
  String get generalError => 'Error';

  @override
  String generalErrorWithDescription(String error) {
    return 'Error: $error';
  }

  @override
  String get generalRetry => 'Retry';

  @override
  String get generalCancel => 'Cancel';

  @override
  String get generalCreate => 'Create';

  @override
  String get generalOk => 'Ok';

  @override
  String get generalSave => 'Save';

  @override
  String get generalDelete => 'Delete';

  @override
  String get generalEdit => 'Edit';

  @override
  String get generalAdd => 'Add';

  @override
  String get generalClose => 'Close';

  @override
  String get generalPrivacyZones => 'Privacy Zones';

  @override
  String get generalSettings => 'Settings';

  @override
  String get generalShare => 'Share';

  @override
  String generalTrackDuration(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String generalTrackDurationShort(String hours, String minutes) {
    return '$hours:$minutes hrs';
  }

  @override
  String generalTrackDistance(String distance) {
    return '$distance km';
  }

  @override
  String get generalExport => 'Export';

  @override
  String get generalLogin => 'Login';

  @override
  String get generalLogout => 'Logout';

  @override
  String get generalRegister => 'Register';

  @override
  String get generalProceed => 'Proceed';

  @override
  String get homeBottomBarHome => 'Home';

  @override
  String get homeBottomBarTracks => 'Tracks';

  @override
  String tracksAppBarSumTracks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
      zero: 'No tracks',
    );
    return '$_temp0';
  }

  @override
  String get tracksNoTracks => 'No tracks available';

  @override
  String get tracksTrackDeleted => 'Track deleted';

  @override
  String get openSenseMapLogin => 'Login with openSenseMap';

  @override
  String get openSenseMapLoginDescription => 'Log in to share your data.';

  @override
  String get openSenseMapLogout => 'Logout';

  @override
  String get openSenseMapEmail => 'Email';

  @override
  String get openSenseMapPassword => 'Password';

  @override
  String get openSenseMapEmailErrorEmpty => 'Email must not be empty';

  @override
  String get openSenseMapEmailErrorInvalid => 'Invalid email address';

  @override
  String get openSenseMapPasswordErrorEmpty => 'Password must not be empty';

  @override
  String get openSenseMapLoginFailed => 'Login failed';

  @override
  String get openSenseMapRegisterName => 'Name';

  @override
  String get openSenseMapRegisterNameErrorEmpty => 'Name must not be empty';

  @override
  String get openSenseMapRegisterPasswordConfirm => 'Confirm password';

  @override
  String get openSenseMapRegisterPasswordConfirmErrorEmpty => 'Password confirmation must not be empty';

  @override
  String get openSenseMapRegisterPasswordErrorMismatch => 'Passwords do not match';

  @override
  String get openSenseMapRegisterPasswordErrorCharacters => 'Password must contain at least 8 characters';

  @override
  String get openSenseMapRegisterFailed => 'Registration failed';

  @override
  String get openSenesMapRegisterAcceptTermsPrefix => 'I accept the';

  @override
  String get openSenseMapRegisterAcceptTermsPrivacy => 'privacy policy';

  @override
  String get openSenseMapRegisterAcceptTermsError => 'You must accept the privacy policy';

  @override
  String get connectionButtonConnect => 'Connect';

  @override
  String get connectionButtonDisconnect => 'Disconnect';

  @override
  String get connectionButtonConnecting => 'Connecting...';

  @override
  String get connectionButtonReconnecting => 'Reconnecting...';

  @override
  String get connectionButtonStart => 'Start';

  @override
  String get connectionButtonStop => 'Stop';

  @override
  String get bleDeviceSelectTitle => 'Tap to connect';

  @override
  String get noBleDevicesFound => 'No senseBoxes found. Please make sure your senseBox is loaded, tap outside this window, and try again.';

  @override
  String get selectOrCreateBox => 'Select or create senseBox:bike';

  @override
  String get createBoxTitle => 'Create senseBox:bike';

  @override
  String get createBoxModel => 'Model';

  @override
  String get createBoxModelErrorEmpty => 'Please select a model';

  @override
  String get createBoxName => 'Name';

  @override
  String get createBoxNameError => 'Name must be between 2 and 50 characters';

  @override
  String get createBoxGeolocationCurrentPosition => 'Your current position will be used';

  @override
  String get openSenseMapBoxSelectionNoBoxes => 'No senseBoxes available';

  @override
  String get openSenseMapBoxSelectionCreateHint => 'Create one using the \'+\' button';

  @override
  String get openSenseMapBoxSelectionUnnamedBox => 'Unnamed senseBox';

  @override
  String get openSenseMapBoxSelectionIncompatible => 'Not compatible with senseBox:bike';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsOther => 'Other';

  @override
  String get settingsVibrateOnDisconnect => 'Vibrate on disconnect';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String settingsVersion(String versionNumber) {
    return 'Version: $versionNumber';
  }

  @override
  String get settingsContact => 'Help or feedback?';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsGithub => 'GitHub issue';

  @override
  String get privacyZonesStart => 'Tap on the map to start drawing a zone. Tap the checkmark to finish.';

  @override
  String get privacyZonesDelete => 'Tap on a zone to delete it. Tap the checkmark to finish.';

  @override
  String get trackDetailsPermissionsError => 'Permission denied to save file to external storage.';

  @override
  String get trackDetailsFileSaved => 'CSV file saved to Downloads folder.';

  @override
  String get trackDetailsExport => 'Track data CSV export.';

  @override
  String get trackDetailsNoData => 'No data available.';

  @override
  String get trackDetailsLoadingError => 'Error loading track.';

  @override
  String get trackDetailsNoTrackData => 'No track available.';

  @override
  String get trackDelete => 'Delete Track';

  @override
  String get trackDeleteConfirmation => 'Are you sure you wish to delete this track?';

  @override
  String get sensorTemperature => 'Temperature';

  @override
  String get sensorHumidity => 'Rel. Humidity';

  @override
  String get sensorFinedustPM10 => 'Finedust PM10';

  @override
  String get sensorFinedustPM4 => 'Finedust PM4';

  @override
  String get sensorFinedustPM25 => 'Finedust PM25';

  @override
  String get sensorFinedustPM1 => 'Finedust PM1';

  @override
  String get sensorDistance => 'Overtaking Distance';

  @override
  String get sensorOvertaking => 'Overtaking Manoeuvre';

  @override
  String get sensorOvertakingShort => 'Overtaking';

  @override
  String get sensorSurface => 'Surface';

  @override
  String get sensorSurfaceAsphalt => 'Surface Asphalt';

  @override
  String get sensorSurfaceAsphaltShort => 'Asphalt';

  @override
  String get sensorSurfaceSett => 'Surface Sett';

  @override
  String get sensorSurfaceSettShort => 'Sett';

  @override
  String get sensorSurfaceCompacted => 'Surface Compacted';

  @override
  String get sensorSurfaceCompactedShort => 'Compacted';

  @override
  String get sensorSurfacePaving => 'Surface Paving';

  @override
  String get sensorSurfacePavingShort => 'Paving';

  @override
  String get sensorSurfaceStanding => 'Standing';

  @override
  String get sensorSurfaceAnomaly => 'Surface Anomaly';

  @override
  String get sensorSpeed => 'Speed';

  @override
  String get sensorAccelerationX => 'Acceleration X';

  @override
  String get sensorAccelerationY => 'Acceleration Y';

  @override
  String get sensorAccelerationZ => 'Acceleration Z';

  @override
  String get sensorGPSLat => 'GPS Latitude';

  @override
  String get sensorGPSLong => 'GPS Longitude';

  @override
  String get sensorGPSSpeed => 'GPS Speed';

  @override
  String get sensorGPSError => 'No GPS Fix';

  @override
  String get sensorAcceleration => 'Acceleration';

  @override
  String get sensorFinedust => 'Finedust';

  @override
  String get sensorDistanceShort => 'Distance';

  @override
  String get campaignLoadError => 'Failed to load list of campaigns.';

  @override
  String get selectCampaign => 'Select campaign';

  @override
  String get noCampaignsAvailable => 'No campaigns available';

  @override
  String get loginScreenTitle => 'openSenseMap Account';

  @override
  String get connectionButtonEnableBluetooth => 'Enable Bluetooth';

  @override
  String get errorNoLocationAccess => 'To record tracks, please allow the app to access the device\'s current location in the phone settings.';

  @override
  String get errorNoScanAccess => 'To connect with senseBox, please allow the app to scan for nearby devices in the phone settings.';

  @override
  String get errorNoSenseBoxSelected => 'To allow upload of sensor data to the cloud, please log in to your openSenseMap account and select the box.';

  @override
  String get errorExportDirectoryAccess => 'Error accessing export directory. Please make sure the app has permission to access the storage.';

  @override
  String get errorLoginFailed => 'Login failed. Please check your credentials.';

  @override
  String get errorRegistrationFailed => 'Registration failed. Please check your credentials.';

  @override
  String get errorBleConnectionFailed => 'Connect to the senseBox was lost. Please make sure Bluetooth is enabled and the senseBox is powered on.';

  @override
  String get errorUploadFailed => 'Data upload failed. Please check your internet connection and try again.';

  @override
  String get errorPermanentAuthentication => 'Authentication failed permanently. Please log in to upload data.';

  @override
  String get selectCsvFormat => 'Select CSV format';

  @override
  String get regularCsv => 'Standard CSV';

  @override
  String get openSenseMapCsv => 'openSenseMap CSV';

  @override
  String get settingsDeleteAllData => 'Delete All Data';

  @override
  String get settingsDeleteAllDataConfirmation => 'Are you sure you want to delete all data? This action is irreversible.';

  @override
  String get settingsDeleteAllDataSuccess => 'All data has been successfully deleted.';

  @override
  String get settingsDeleteAllDataError => 'Failed to delete all data. Please try again.';

  @override
  String get accountManagement => 'Account Management';

  @override
  String get deleteAllHint => 'This will delete all your tracks from the app.';

  @override
  String get generalConfirmation => 'Confirmation';

  @override
  String get privacyPolicyAccept => 'I have read and accept the Privacy Policy.';

  @override
  String get trackNoGeolocations => 'No geolocations available for this track.';

  @override
  String get tracksAppBarTitle => 'Your tracks';

  @override
  String get loadMore => 'Load more';

  @override
  String get tracksStatisticsTitle => 'Track Statistics';

  @override
  String get tracksStatisticsTotalData => 'Total Data';

  @override
  String get tracksStatisticsThisWeek => 'This Week';

  @override
  String get tracksStatisticsRidesInfo => 'rides completed';

  @override
  String get tracksStatisticsDistanceInfo => 'distance traveled';

  @override
  String get tracksStatisticsTimeInfo => 'time spent on the road';

  @override
  String get trackStatistics => 'Track Statistics';

  @override
  String get uploadProgressTitle => 'Upload Progress';

  @override
  String get uploadProgressPreparing => 'Preparing upload...';

  @override
  String get uploadProgressUploading => 'Uploading track data...';

  @override
  String get uploadProgressRetrying => 'Retrying upload...';

  @override
  String get uploadProgressCompleted => 'Upload completed successfully';

  @override
  String get uploadProgressFailed => 'Upload failed';

  @override
  String get uploadProgressAuthenticationFailed => 'Authentication required';

  @override
  String uploadProgressChunks(int completed, int total) {
    return '$completed of $total chunks uploaded';
  }

  @override
  String uploadProgressPercentage(int percentage) {
    return '$percentage% complete';
  }

  @override
  String get uploadProgressAuthenticationError => 'Please log in to upload data.';

  @override
  String get uploadProgressNetworkError => 'Network connection failed. Please check your internet connection and try again.';

  @override
  String get uploadProgressGenericError => 'Upload failed. Please try again.';

  @override
  String get trackStatusUploaded => 'Uploaded';

  @override
  String get trackStatusNotUploaded => 'Not uploaded';

  @override
  String get trackStatusUploadFailed => 'Upload failed';

  @override
  String get trackFilterAll => 'All tracks';

  @override
  String get trackFilterUnuploaded => 'Unuploaded only';

  @override
  String get trackUploadRetryFailed => 'Upload retry failed. Please try again.';
}
