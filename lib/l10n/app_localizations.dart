import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @createBoxAddCustomTag.
  ///
  /// In en, this message translates to:
  /// **'Add custom group tag'**
  String get createBoxAddCustomTag;

  /// No description provided for @createBoxCustomTag.
  ///
  /// In en, this message translates to:
  /// **'Custom group tag'**
  String get createBoxCustomTag;

  /// No description provided for @createBoxCustomTagHelper.
  ///
  /// In en, this message translates to:
  /// **'You can separate tags with commas'**
  String get createBoxCustomTagHelper;

  /// No description provided for @generalLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get generalLoading;

  /// No description provided for @generalError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get generalError;

  /// No description provided for @generalErrorWithDescription.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String generalErrorWithDescription(String error);

  /// No description provided for @generalCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get generalCancel;

  /// No description provided for @generalCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get generalCreate;

  /// No description provided for @generalOk.
  ///
  /// In en, this message translates to:
  /// **'Ok'**
  String get generalOk;

  /// No description provided for @generalSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get generalSave;

  /// No description provided for @generalDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get generalDelete;

  /// No description provided for @generalEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get generalEdit;

  /// No description provided for @generalAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get generalAdd;

  /// No description provided for @generalClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get generalClose;

  /// No description provided for @generalUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get generalUpload;

  /// No description provided for @generalPrivacyZones.
  ///
  /// In en, this message translates to:
  /// **'Privacy Zones'**
  String get generalPrivacyZones;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get generalSettings;

  /// No description provided for @generalShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get generalShare;

  /// No description provided for @generalTrackDuration.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String generalTrackDuration(int hours, int minutes);

  /// No description provided for @generalTrackDurationShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}:{minutes} hrs'**
  String generalTrackDurationShort(String hours, String minutes);

  /// No description provided for @generalTrackDistance.
  ///
  /// In en, this message translates to:
  /// **'{distance} km'**
  String generalTrackDistance(String distance);

  /// No description provided for @generalExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get generalExport;

  /// No description provided for @generalLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get generalLogin;

  /// No description provided for @generalLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get generalLogout;

  /// No description provided for @generalRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get generalRegister;

  /// No description provided for @generalProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get generalProceed;

  /// No description provided for @homeBottomBarHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeBottomBarHome;

  /// No description provided for @homeBottomBarTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get homeBottomBarTracks;

  /// No description provided for @tracksAppBarSumTracks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tracks} =1{1 track} other{{count} tracks}}'**
  String tracksAppBarSumTracks(num count);

  /// No description provided for @tracksNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks available'**
  String get tracksNoTracks;

  /// No description provided for @tracksTrackDeleted.
  ///
  /// In en, this message translates to:
  /// **'Track deleted'**
  String get tracksTrackDeleted;

  /// No description provided for @openSenseMapLogin.
  ///
  /// In en, this message translates to:
  /// **'Login with openSenseMap'**
  String get openSenseMapLogin;

  /// No description provided for @openSenseMapLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Log in to share your data.'**
  String get openSenseMapLoginDescription;

  /// No description provided for @openSenseMapLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get openSenseMapLogout;

  /// No description provided for @openSenseMapEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get openSenseMapEmail;

  /// No description provided for @openSenseMapPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get openSenseMapPassword;

  /// No description provided for @openSenseMapEmailErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Email must not be empty'**
  String get openSenseMapEmailErrorEmpty;

  /// No description provided for @openSenseMapEmailErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get openSenseMapEmailErrorInvalid;

  /// No description provided for @openSenseMapPasswordErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password must not be empty'**
  String get openSenseMapPasswordErrorEmpty;

  /// No description provided for @openSenseMapLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get openSenseMapLoginFailed;

  /// No description provided for @openSenseMapRegisterName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get openSenseMapRegisterName;

  /// No description provided for @openSenseMapRegisterNameErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name must not be empty'**
  String get openSenseMapRegisterNameErrorEmpty;

  /// No description provided for @openSenseMapRegisterPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get openSenseMapRegisterPasswordConfirm;

  /// No description provided for @openSenseMapRegisterPasswordConfirmErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password confirmation must not be empty'**
  String get openSenseMapRegisterPasswordConfirmErrorEmpty;

  /// No description provided for @openSenseMapRegisterPasswordErrorMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get openSenseMapRegisterPasswordErrorMismatch;

  /// No description provided for @openSenseMapRegisterPasswordErrorCharacters.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 8 characters'**
  String get openSenseMapRegisterPasswordErrorCharacters;

  /// No description provided for @openSenseMapRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get openSenseMapRegisterFailed;

  /// No description provided for @openSenesMapRegisterAcceptTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I accept the'**
  String get openSenesMapRegisterAcceptTermsPrefix;

  /// No description provided for @openSenseMapRegisterAcceptTermsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get openSenseMapRegisterAcceptTermsPrivacy;

  /// No description provided for @openSenseMapRegisterAcceptTermsError.
  ///
  /// In en, this message translates to:
  /// **'You must accept the privacy policy'**
  String get openSenseMapRegisterAcceptTermsError;

  /// No description provided for @connectionButtonConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectionButtonConnect;

  /// No description provided for @connectionButtonDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get connectionButtonDisconnect;

  /// No description provided for @connectionButtonConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectionButtonConnecting;

  /// No description provided for @connectionButtonReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get connectionButtonReconnecting;

  /// No description provided for @connectionButtonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get connectionButtonStart;

  /// No description provided for @connectionButtonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get connectionButtonStop;

  /// No description provided for @bleDeviceSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to connect'**
  String get bleDeviceSelectTitle;

  /// No description provided for @noBleDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No senseBoxes found. Please make sure your senseBox is loaded, tap outside this window, and try again.'**
  String get noBleDevicesFound;

  /// No description provided for @selectOrCreateBox.
  ///
  /// In en, this message translates to:
  /// **'Select or create senseBox:bike'**
  String get selectOrCreateBox;

  /// No description provided for @createBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'Create senseBox:bike'**
  String get createBoxTitle;

  /// No description provided for @createBoxModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get createBoxModel;

  /// No description provided for @createBoxModelErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please select a model'**
  String get createBoxModelErrorEmpty;

  /// No description provided for @createBoxName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createBoxName;

  /// No description provided for @createBoxNameError.
  ///
  /// In en, this message translates to:
  /// **'Name must be between 2 and 50 characters'**
  String get createBoxNameError;

  /// No description provided for @createBoxGeolocationCurrentPosition.
  ///
  /// In en, this message translates to:
  /// **'Your current position will be used'**
  String get createBoxGeolocationCurrentPosition;

  /// No description provided for @openSenseMapBoxSelectionNoBoxes.
  ///
  /// In en, this message translates to:
  /// **'No senseBoxes available'**
  String get openSenseMapBoxSelectionNoBoxes;

  /// No description provided for @openSenseMapBoxSelectionCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Create one using the \'+\' button'**
  String get openSenseMapBoxSelectionCreateHint;

  /// No description provided for @openSenseMapBoxSelectionUnnamedBox.
  ///
  /// In en, this message translates to:
  /// **'Unnamed senseBox'**
  String get openSenseMapBoxSelectionUnnamedBox;

  /// No description provided for @openSenseMapBoxSelectionIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Not compatible with senseBox:bike'**
  String get openSenseMapBoxSelectionIncompatible;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsOther;

  /// No description provided for @settingsVibrateOnDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on disconnect'**
  String get settingsVibrateOnDisconnect;

  /// No description provided for @settingsUploadMode.
  ///
  /// In en, this message translates to:
  /// **'Upload Mode'**
  String get settingsUploadMode;

  /// No description provided for @settingsUploadModeDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct Upload (Beta)'**
  String get settingsUploadModeDirect;

  /// No description provided for @settingsUploadModePostRide.
  ///
  /// In en, this message translates to:
  /// **'Post-Ride Upload'**
  String get settingsUploadModePostRide;

  /// No description provided for @settingsUploadModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose when to upload your data during recording'**
  String get settingsUploadModeDescription;

  /// No description provided for @settingsUploadModeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current: {mode}'**
  String settingsUploadModeCurrent(String mode);

  /// No description provided for @settingsUploadModePostRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload data after recording stops'**
  String get settingsUploadModePostRideTitle;

  /// No description provided for @settingsUploadModePostRideDescription.
  ///
  /// In en, this message translates to:
  /// **'• Data is stored locally during recording\n• Upload happens all at once when you finish\n• More reliable and stable\n• Uses less battery during recording'**
  String get settingsUploadModePostRideDescription;

  /// No description provided for @settingsUploadModeDirectTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload data in real-time during recording (experimental)'**
  String get settingsUploadModeDirectTitle;

  /// No description provided for @settingsUploadModeDirectDescription.
  ///
  /// In en, this message translates to:
  /// **'• Data is uploaded immediately as it\'s collected\n• Real-time data sharing (experimental)\n• Requires stable internet connection\n• May use more battery during recording'**
  String get settingsUploadModeDirectDescription;

  /// No description provided for @settingsApiUrl.
  ///
  /// In en, this message translates to:
  /// **'API URL'**
  String get settingsApiUrl;

  /// No description provided for @settingsApiUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter the API endpoint for data uploads'**
  String get settingsApiUrlHelper;

  /// No description provided for @settingsApiUrlError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL (e.g., https://api.opensensemap.org)'**
  String get settingsApiUrlError;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version: {versionNumber}'**
  String settingsVersion(String versionNumber);

  /// No description provided for @settingsContact.
  ///
  /// In en, this message translates to:
  /// **'Help or feedback?'**
  String get settingsContact;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get settingsEmail;

  /// No description provided for @settingsGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub issue'**
  String get settingsGithub;

  /// No description provided for @privacyZonesStart.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to start drawing a zone. Tap the checkmark to finish.'**
  String get privacyZonesStart;

  /// No description provided for @privacyZonesDelete.
  ///
  /// In en, this message translates to:
  /// **'Tap on a zone to delete it. Tap the checkmark to finish.'**
  String get privacyZonesDelete;

  /// No description provided for @trackDetailsPermissionsError.
  ///
  /// In en, this message translates to:
  /// **'Permission denied to save file to external storage.'**
  String get trackDetailsPermissionsError;

  /// No description provided for @trackDetailsFileSaved.
  ///
  /// In en, this message translates to:
  /// **'CSV file saved to Downloads folder.'**
  String get trackDetailsFileSaved;

  /// No description provided for @trackDetailsExport.
  ///
  /// In en, this message translates to:
  /// **'Track data CSV export.'**
  String get trackDetailsExport;

  /// No description provided for @trackDetailsLoadingError.
  ///
  /// In en, this message translates to:
  /// **'Error loading track.'**
  String get trackDetailsLoadingError;

  /// No description provided for @trackDetailsNoTrackData.
  ///
  /// In en, this message translates to:
  /// **'No track available.'**
  String get trackDetailsNoTrackData;

  /// No description provided for @trackDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Track'**
  String get trackDelete;

  /// No description provided for @trackDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you wish to delete this track?'**
  String get trackDeleteConfirmation;

  /// No description provided for @sensorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get sensorTemperature;

  /// No description provided for @sensorHumidity.
  ///
  /// In en, this message translates to:
  /// **'Rel. Humidity'**
  String get sensorHumidity;

  /// No description provided for @sensorFinedustPM10.
  ///
  /// In en, this message translates to:
  /// **'Finedust PM10'**
  String get sensorFinedustPM10;

  /// No description provided for @sensorFinedustPM4.
  ///
  /// In en, this message translates to:
  /// **'Finedust PM4'**
  String get sensorFinedustPM4;

  /// No description provided for @sensorFinedustPM25.
  ///
  /// In en, this message translates to:
  /// **'Finedust PM25'**
  String get sensorFinedustPM25;

  /// No description provided for @sensorFinedustPM1.
  ///
  /// In en, this message translates to:
  /// **'Finedust PM1'**
  String get sensorFinedustPM1;

  /// No description provided for @sensorDistance.
  ///
  /// In en, this message translates to:
  /// **'Overtaking Distance'**
  String get sensorDistance;

  /// No description provided for @sensorOvertaking.
  ///
  /// In en, this message translates to:
  /// **'Overtaking Manoeuvre'**
  String get sensorOvertaking;

  /// No description provided for @sensorOvertakingShort.
  ///
  /// In en, this message translates to:
  /// **'Overtaking'**
  String get sensorOvertakingShort;

  /// No description provided for @sensorSurface.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get sensorSurface;

  /// No description provided for @sensorSurfaceAsphalt.
  ///
  /// In en, this message translates to:
  /// **'Surface Asphalt'**
  String get sensorSurfaceAsphalt;

  /// No description provided for @sensorSurfaceAsphaltShort.
  ///
  /// In en, this message translates to:
  /// **'Asphalt'**
  String get sensorSurfaceAsphaltShort;

  /// No description provided for @sensorSurfaceSett.
  ///
  /// In en, this message translates to:
  /// **'Surface Sett'**
  String get sensorSurfaceSett;

  /// No description provided for @sensorSurfaceSettShort.
  ///
  /// In en, this message translates to:
  /// **'Sett'**
  String get sensorSurfaceSettShort;

  /// No description provided for @sensorSurfaceCompacted.
  ///
  /// In en, this message translates to:
  /// **'Surface Compacted'**
  String get sensorSurfaceCompacted;

  /// No description provided for @sensorSurfaceCompactedShort.
  ///
  /// In en, this message translates to:
  /// **'Compacted'**
  String get sensorSurfaceCompactedShort;

  /// No description provided for @sensorSurfacePaving.
  ///
  /// In en, this message translates to:
  /// **'Surface Paving'**
  String get sensorSurfacePaving;

  /// No description provided for @sensorSurfacePavingShort.
  ///
  /// In en, this message translates to:
  /// **'Paving'**
  String get sensorSurfacePavingShort;

  /// No description provided for @sensorSurfaceStanding.
  ///
  /// In en, this message translates to:
  /// **'Standing'**
  String get sensorSurfaceStanding;

  /// No description provided for @sensorSurfaceAnomaly.
  ///
  /// In en, this message translates to:
  /// **'Surface Anomaly'**
  String get sensorSurfaceAnomaly;

  /// No description provided for @sensorSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get sensorSpeed;

  /// No description provided for @sensorAccelerationX.
  ///
  /// In en, this message translates to:
  /// **'Acceleration X'**
  String get sensorAccelerationX;

  /// No description provided for @sensorAccelerationY.
  ///
  /// In en, this message translates to:
  /// **'Acceleration Y'**
  String get sensorAccelerationY;

  /// No description provided for @sensorAccelerationZ.
  ///
  /// In en, this message translates to:
  /// **'Acceleration Z'**
  String get sensorAccelerationZ;

  /// No description provided for @sensorGPSLat.
  ///
  /// In en, this message translates to:
  /// **'GPS Latitude'**
  String get sensorGPSLat;

  /// No description provided for @sensorGPSLong.
  ///
  /// In en, this message translates to:
  /// **'GPS Longitude'**
  String get sensorGPSLong;

  /// No description provided for @sensorGPSSpeed.
  ///
  /// In en, this message translates to:
  /// **'GPS Speed'**
  String get sensorGPSSpeed;

  /// No description provided for @sensorGPSError.
  ///
  /// In en, this message translates to:
  /// **'No GPS Fix'**
  String get sensorGPSError;

  /// No description provided for @sensorAcceleration.
  ///
  /// In en, this message translates to:
  /// **'Acceleration'**
  String get sensorAcceleration;

  /// No description provided for @sensorFinedust.
  ///
  /// In en, this message translates to:
  /// **'Finedust'**
  String get sensorFinedust;

  /// No description provided for @sensorDistanceShort.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get sensorDistanceShort;

  /// No description provided for @campaignLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load list of campaigns.'**
  String get campaignLoadError;

  /// No description provided for @selectCampaign.
  ///
  /// In en, this message translates to:
  /// **'Select campaign'**
  String get selectCampaign;

  /// No description provided for @noCampaignsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No campaigns available'**
  String get noCampaignsAvailable;

  /// No description provided for @loginScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'openSenseMap Account'**
  String get loginScreenTitle;

  /// No description provided for @connectionButtonEnableBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Enable Bluetooth'**
  String get connectionButtonEnableBluetooth;

  /// No description provided for @errorNoLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled or access is denied. To record tracks, please enable location services and allow the app to access your location in the phone settings.'**
  String get errorNoLocationAccess;

  /// No description provided for @errorNoScanAccess.
  ///
  /// In en, this message translates to:
  /// **'To connect with senseBox, please allow the app to scan for nearby devices in the phone settings.'**
  String get errorNoScanAccess;

  /// No description provided for @errorNoSenseBoxSelected.
  ///
  /// In en, this message translates to:
  /// **'To allow upload of sensor data to the cloud, please log in to your openSenseMap account and select the box.'**
  String get errorNoSenseBoxSelected;

  /// No description provided for @loginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please log in to share sensor data'**
  String get loginRequiredMessage;

  /// No description provided for @errorExportDirectoryAccess.
  ///
  /// In en, this message translates to:
  /// **'Error accessing export directory. Please make sure the app has permission to access the storage.'**
  String get errorExportDirectoryAccess;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try once again.'**
  String get errorLoginFailed;

  /// No description provided for @errorRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please check your credentials and try once again.'**
  String get errorRegistrationFailed;

  /// No description provided for @errorBleConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection to the senseBox was lost. Please make sure Bluetooth is enabled and the senseBox is powered on.'**
  String get errorBleConnectionFailed;

  /// No description provided for @errorUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Data upload failed. Please check your internet connection and try again.'**
  String get errorUploadFailed;

  /// No description provided for @errorPermanentAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed permanently. Please log in to upload data.'**
  String get errorPermanentAuthentication;

  /// No description provided for @selectCsvFormat.
  ///
  /// In en, this message translates to:
  /// **'Select CSV format'**
  String get selectCsvFormat;

  /// No description provided for @regularCsv.
  ///
  /// In en, this message translates to:
  /// **'Standard CSV'**
  String get regularCsv;

  /// No description provided for @openSenseMapCsv.
  ///
  /// In en, this message translates to:
  /// **'openSenseMap CSV'**
  String get openSenseMapCsv;

  /// No description provided for @settingsDeleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete All Data'**
  String get settingsDeleteAllData;

  /// No description provided for @settingsDeleteAllDataConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all data? This action is irreversible.'**
  String get settingsDeleteAllDataConfirmation;

  /// No description provided for @settingsDeleteAllDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data has been successfully deleted.'**
  String get settingsDeleteAllDataSuccess;

  /// No description provided for @settingsDeleteAllDataError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete all data. Please try again.'**
  String get settingsDeleteAllDataError;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get accountManagement;

  /// No description provided for @deleteAllHint.
  ///
  /// In en, this message translates to:
  /// **'This will delete all your tracks from the app.'**
  String get deleteAllHint;

  /// No description provided for @generalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get generalConfirmation;

  /// No description provided for @privacyPolicyAccept.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the Privacy Policy.'**
  String get privacyPolicyAccept;

  /// No description provided for @trackNoGeolocations.
  ///
  /// In en, this message translates to:
  /// **'No geolocations available for this track.'**
  String get trackNoGeolocations;

  /// No description provided for @tracksAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Your tracks'**
  String get tracksAppBarTitle;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @tracksStatisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Track Statistics'**
  String get tracksStatisticsTitle;

  /// No description provided for @tracksStatisticsTotalData.
  ///
  /// In en, this message translates to:
  /// **'Total Data'**
  String get tracksStatisticsTotalData;

  /// No description provided for @tracksStatisticsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get tracksStatisticsThisWeek;

  /// No description provided for @tracksStatisticsRidesInfo.
  ///
  /// In en, this message translates to:
  /// **'rides completed'**
  String get tracksStatisticsRidesInfo;

  /// No description provided for @tracksStatisticsDistanceInfo.
  ///
  /// In en, this message translates to:
  /// **'distance traveled'**
  String get tracksStatisticsDistanceInfo;

  /// No description provided for @tracksStatisticsTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'time spent on the road'**
  String get tracksStatisticsTimeInfo;

  /// No description provided for @trackStatistics.
  ///
  /// In en, this message translates to:
  /// **'Track Statistics'**
  String get trackStatistics;

  /// No description provided for @uploadProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Progress'**
  String get uploadProgressTitle;

  /// No description provided for @uploadProgressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing upload...'**
  String get uploadProgressPreparing;

  /// No description provided for @uploadProgressUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading track data...'**
  String get uploadProgressUploading;

  /// No description provided for @uploadProgressInfo.
  ///
  /// In en, this message translates to:
  /// **'Do not close the app while uploading. It can take some time depending on your track length.\n\nIf you would like to upload your track data later, you can do that from track overview screen.'**
  String get uploadProgressInfo;

  /// No description provided for @uploadProgressRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying upload...'**
  String get uploadProgressRetrying;

  /// No description provided for @uploadProgressCompleted.
  ///
  /// In en, this message translates to:
  /// **'Upload completed successfully'**
  String get uploadProgressCompleted;

  /// No description provided for @uploadProgressFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadProgressFailed;

  /// No description provided for @uploadProgressAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get uploadProgressAuthenticationFailed;

  /// No description provided for @uploadProgressChunks.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total, plural, =0{0 chunks} =1{1 chunk} other{{total} chunks}} uploaded'**
  String uploadProgressChunks(int completed, int total);

  /// No description provided for @uploadProgressPercentage.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% complete'**
  String uploadProgressPercentage(int percentage);

  /// No description provided for @uploadProgressAuthenticationError.
  ///
  /// In en, this message translates to:
  /// **'Please log in to upload data.'**
  String get uploadProgressAuthenticationError;

  /// No description provided for @uploadProgressNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed. Please check your internet connection and try again.'**
  String get uploadProgressNetworkError;

  /// No description provided for @uploadProgressGenericError.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get uploadProgressGenericError;

  /// No description provided for @uploadConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Track Data'**
  String get uploadConfirmTitle;

  /// No description provided for @uploadConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to upload your track data now?'**
  String get uploadConfirmMessage;

  /// No description provided for @uploadConfirmUploadNow.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadConfirmUploadNow;

  /// No description provided for @trackStatusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get trackStatusUploaded;

  /// No description provided for @trackStatusUploadedAt.
  ///
  /// In en, this message translates to:
  /// **'Uploaded on {date}'**
  String trackStatusUploadedAt(String date);

  /// No description provided for @trackStatusNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get trackStatusNotUploaded;

  /// No description provided for @trackStatusUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get trackStatusUploadFailed;

  /// No description provided for @trackStatusUploadFailedAt.
  ///
  /// In en, this message translates to:
  /// **'Upload failed on {date}'**
  String trackStatusUploadFailedAt(Object date);

  /// No description provided for @trackDirectUploadInfo.
  ///
  /// In en, this message translates to:
  /// **'This track data was uploaded in real time during your ride. If you\'d like to re-upload it, you can use the upload button above.'**
  String get trackDirectUploadInfo;

  /// No description provided for @trackUploadAttempts.
  ///
  /// In en, this message translates to:
  /// **'Upload attempts'**
  String get trackUploadAttempts;

  /// No description provided for @trackLastAttempt.
  ///
  /// In en, this message translates to:
  /// **'Last attempt'**
  String get trackLastAttempt;

  /// No description provided for @trackStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get trackStatus;

  /// No description provided for @trackDirectUploadAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'This track failed to upload in real-time because you weren\'t logged in. Please log in and try uploading again.'**
  String get trackDirectUploadAuthFailed;

  /// No description provided for @trackFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get trackFilterAll;

  /// No description provided for @trackFilterUnuploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get trackFilterUnuploaded;

  /// No description provided for @trackUploadRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload retry failed. Please try again.'**
  String get trackUploadRetryFailed;

  /// No description provided for @errorTrackNoGeolocations.
  ///
  /// In en, this message translates to:
  /// **'Track has no geolocation data and cannot be uploaded.'**
  String get errorTrackNoGeolocations;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de': return AppLocalizationsDe();
    case 'en': return AppLocalizationsEn();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
