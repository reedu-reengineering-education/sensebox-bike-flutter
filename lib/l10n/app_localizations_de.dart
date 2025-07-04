// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get generalLoading => 'Lädt...';

  @override
  String get generalError => 'Fehler';

  @override
  String generalErrorWithDescription(String error) {
    return 'Fehler: $error';
  }

  @override
  String get generalRetry => 'Erneut versuchen';

  @override
  String get generalCancel => 'Abbrechen';

  @override
  String get generalCreate => 'Erstellen';

  @override
  String get generalOk => 'Ok';

  @override
  String get generalSave => 'Speichern';

  @override
  String get generalDelete => 'Löschen';

  @override
  String get generalEdit => 'Bearbeiten';

  @override
  String get generalAdd => 'Hinzufügen';

  @override
  String get generalClose => 'Schließen';

  @override
  String get generalPrivacyZones => 'Privatzonen';

  @override
  String get generalSettings => 'Einstellungen';

  @override
  String get generalShare => 'Teilen';

  @override
  String generalTrackDuration(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String generalTrackDistance(String distance) {
    return '$distance km';
  }

  @override
  String get generalExport => 'Exportieren';

  @override
  String get generalLogin => 'Anmelden';

  @override
  String get generalLogout => 'Abmelden';

  @override
  String get generalRegister => 'Registrieren';

  @override
  String get generalProceed => 'Fortfahren';

  @override
  String get homeBottomBarHome => 'Start';

  @override
  String get homeBottomBarTracks => 'Tracks';

  @override
  String get tracksAppBarTitle => 'Tracks';

  @override
  String tracksAppBarSumTracks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tracks',
      one: '1 Track',
      zero: 'Keine Tracks',
    );
    return '$_temp0';
  }

  @override
  String get tracksNoTracks => 'Keine Tracks verfügbar';

  @override
  String get tracksTrackDeleted => 'Track gelöscht';

  @override
  String get openSenseMapLogin => 'Mit openSenseMap anmelden';

  @override
  String get openSenseMapLogout => 'Ausloggen';

  @override
  String get openSenseMapEmail => 'E-Mail';

  @override
  String get openSenseMapPassword => 'Passwort';

  @override
  String get openSenseMapEmailErrorEmpty => 'E-Mail darf nicht leer sein';

  @override
  String get openSenseMapEmailErrorInvalid => 'Ungültige E-Mail-Adresse';

  @override
  String get openSenseMapPasswordErrorEmpty => 'Passwort darf nicht leer sein';

  @override
  String get openSenseMapLoginFailed => 'Anmeldung fehlgeschlagen';

  @override
  String get openSenseMapRegisterName => 'Name';

  @override
  String get openSenseMapRegisterNameErrorEmpty => 'Name darf nicht leer sein';

  @override
  String get openSenseMapRegisterPasswordConfirm => 'Passwort bestätigen';

  @override
  String get openSenseMapRegisterPasswordConfirmErrorEmpty =>
      'Passwort darf nicht leer sein';

  @override
  String get openSenseMapRegisterPasswordErrorMismatch =>
      'Passwörter stimmen nicht überein';

  @override
  String get openSenseMapRegisterPasswordErrorCharacters =>
      'Passwort muss mindestens 8 Zeichen enthalten';

  @override
  String get openSenseMapRegisterFailed => 'Registrierung fehlgeschlagen';

  @override
  String get openSenesMapRegisterAcceptTermsPrefix => 'Ich akzeptiere die';

  @override
  String get openSenseMapRegisterAcceptTermsPrivacy =>
      'Datenschutzbestimmungen';

  @override
  String get openSenseMapRegisterAcceptTermsError =>
      'Sie müssen die Datenschutzbestimmungen akzeptieren';

  @override
  String get connectionButtonConnect => 'Verbinden';

  @override
  String get connectionButtonDisconnect => 'Trennen';

  @override
  String get connectionButtonConnecting => 'Verbinden...';

  @override
  String get connectionButtonReconnecting => 'Erneut verbinden...';

  @override
  String get connectionButtonStart => 'Start';

  @override
  String get connectionButtonStop => 'Stop';

  @override
  String get bleDeviceSelectTitle => 'Tippen, um zu verbinden';

  @override
  String get noBleDevicesFound =>
      'Keine senseBoxen gefunden. Bitte stelle sicher, dass deine senseBox eingeschaltet ist, tippe dann außerhalb dieses Fensters und versuche es erneut.';

  @override
  String get createBoxTitle => 'senseBox:bike erstellen';

  @override
  String get createBoxModel => 'Modell';

  @override
  String get createBoxModelErrorEmpty => 'Bitte wähle ein Modell';

  @override
  String get createBoxName => 'Name';

  @override
  String get createBoxNameError =>
      'Name muss zwischen 2 und 50 Zeichen lang sein';

  @override
  String get createBoxGeolocationCurrentPosition =>
      'Deine aktuelle Position wird verwendet';

  @override
  String get openSenseMapBoxSelectionNoBoxes => 'Keine senseBox verfügbar';

  @override
  String get openSenseMapBoxSelectionCreateHint =>
      'Erstelle eine mit dem \'+\' Button';

  @override
  String get openSenseMapBoxSelectionUnnamedBox => 'Unbenannte senseBox';

  @override
  String get openSenseMapBoxSelectionIncompatible =>
      'Nicht kompatibel mit senseBox:bike';

  @override
  String get settingsGeneral => 'Allgemeine';

  @override
  String get settingsOther => 'Andere';

  @override
  String get settingsVibrateOnDisconnect => 'Vibration bei Verbindungsabbruch';

  @override
  String get settingsAbout => 'Über die App';

  @override
  String get settingsPrivacyPolicy => 'Datenschutz';

  @override
  String settingsVersion(String versionNumber) {
    return 'Version: $versionNumber';
  }

  @override
  String get settingsContact => 'Hilfe oder Feedback?';

  @override
  String get settingsEmail => 'E-Mail';

  @override
  String get settingsGithub => 'GitHub issue';

  @override
  String get privacyZonesStart =>
      'Tippen Sie auf die Karte, um mit dem Zeichnen einer Zone zu beginnen. Tippen Sie auf das Häkchen, um den Vorgang zu beenden.';

  @override
  String get privacyZonesDelete =>
      'Tippen Sie auf eine Zone, um sie zu löschen. Tippen Sie auf das Häkchen, um den Vorgang zu beenden.';

  @override
  String get trackDetailsPermissionsError =>
      'Keine Berechtigung zum Speichern der Datei auf externem Speicher.';

  @override
  String get trackDetailsFileSaved =>
      'Die CSV-Datei wird im Ordner Downloads gespeichert.';

  @override
  String get trackDetailsExport => 'CSV-Export von Trackdaten.';

  @override
  String get trackDetailsNoData => 'Daten nicht verfügbar.';

  @override
  String get trackDetailsLoadingError => 'Fehler beim Laden des Tracks.';

  @override
  String get trackDetailsNoTrackData => 'Kein Track verfügbar.';

  @override
  String get trackDelete => 'Track löschen';

  @override
  String get trackDeleteConfirmation =>
      'Wollen Sie diesen Track wirklich löschen?';

  @override
  String get sensorTemperature => 'Temperatur';

  @override
  String get sensorHumidity => 'Rel. Luftfeuchtigkeit';

  @override
  String get sensorFinedustPM10 => 'Feinstaub PM10';

  @override
  String get sensorFinedustPM4 => 'Feinstaub PM4';

  @override
  String get sensorFinedustPM25 => 'Feinstaub PM2,5';

  @override
  String get sensorFinedustPM1 => 'Feinstaub PM1';

  @override
  String get sensorDistance => 'Überholabstand';

  @override
  String get sensorOvertaking => 'Überholmanöver';

  @override
  String get sensorOvertakingShort => 'Überholen';

  @override
  String get sensorSurface => 'Oberfläche';

  @override
  String get sensorSurfaceAsphalt => 'Oberfläche Asphalt';

  @override
  String get sensorSurfaceAsphaltShort => 'Asphalt';

  @override
  String get sensorSurfaceSett => 'Oberfläche Pflasterstein';

  @override
  String get sensorSurfaceSettShort => 'Pflasterstein';

  @override
  String get sensorSurfaceCompacted => 'Oberfläche verdichtet';

  @override
  String get sensorSurfaceCompactedShort => 'Verdichtet';

  @override
  String get sensorSurfacePaving => 'Oberfläche Pflasterung';

  @override
  String get sensorSurfacePavingShort => 'Pflasterung';

  @override
  String get sensorSurfaceStanding => 'Stehend';

  @override
  String get sensorSurfaceAnomaly => 'Oberfl. Anomalie';

  @override
  String get sensorSpeed => 'Geschwindigkeit';

  @override
  String get sensorAccelerationX => 'Beschleunigung X';

  @override
  String get sensorAccelerationY => 'Beschleunigung Y';

  @override
  String get sensorAccelerationZ => 'Beschleunigung Z';

  @override
  String get sensorGPSLat => 'GPS Breitengrad';

  @override
  String get sensorGPSLong => 'GPS Längengrad';

  @override
  String get sensorGPSSpeed => 'GPS Geschwindigkeit';

  @override
  String get sensorGPSError => 'Kein GPS-Fix';

  @override
  String get sensorAcceleration => 'Beschleunigung';

  @override
  String get sensorFinedust => 'Feinstaub';

  @override
  String get sensorDistanceShort => 'Abstand';

  @override
  String get campaignLoadError =>
      'Die Liste der Kampagnen konnte nicht geladen werden.';

  @override
  String get selectCampaign => 'Kampagne auswählen';

  @override
  String get noCampaignsAvailable => 'Keine Kampagnen verfügbar';

  @override
  String get loginScreenTitle => 'openSenseMap Konto';

  @override
  String get connectionButtonEnableBluetooth => 'Bluetooth aktivieren';

  @override
  String get errorNoLocationAccess =>
      'Um Tracks aufzuzeichnen, erlauben Sie bitte der App in den Telefoneinstellungen den Zugriff auf den aktuellen Standort des Geräts.';

  @override
  String get errorNoScanAccess =>
      'Um eine Verbindung mit senseBox herzustellen, erlauben Sie bitte der App in den Telefoneinstellungen, nach Geräten in der Nähe zu scannen.';

  @override
  String get errorNoSenseBoxSelected =>
      'Um den Upload von Sensordaten in die Cloud zu erlauben, melden Sie sich bitte bei Ihrem openSenseMap-Konto an und aktivieren Sie das Kästchen.';

  @override
  String get errorExportDirectoryAccess =>
      'Bitte erlaube dieser App in den Telefoneinstellungen den Zugriff auf den externen Speicher.';

  @override
  String get errorLoginFailed =>
      'Anmeldung fehlgeschlagen. Bitte überprüfen Sie Ihre Anmeldedaten.';

  @override
  String get errorRegistrationFailed =>
      'Registrierung fehlgeschlagen. Bitte überprüfen Sie Ihre Anmeldedaten.';

  @override
  String get errorBleConnectionFailed =>
      'Die Verbindung zur senseBox wurde unterbrochen. Bitte stellen Sie sicher, dass Bluetooth aktiviert ist und die senseBox eingeschaltet ist.';

  @override
  String get selectCsvFormat => 'CSV-Format auswählen';

  @override
  String get regularCsv => 'Standard CSV';

  @override
  String get openSenseMapCsv => 'openSenseMap CSV';

  @override
  String get settingsDeleteAllData => 'Alle Daten löschen';

  @override
  String get settingsDeleteAllDataConfirmation =>
      'Sind Sie sicher, dass Sie alle Daten löschen möchten? Diese Aktion ist nicht umkehrbar.';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Alle Daten wurden erfolgreich gelöscht.';

  @override
  String get settingsDeleteAllDataError =>
      'Fehler beim Löschen aller Daten. Bitte versuchen Sie es erneut.';

  @override
  String get accountManagement => 'Kontoverwaltung';

  @override
  String get deleteAllHint => 'Dies löscht alle Ihre Tracks aus der App.';

  @override
  String get generalConfirmation => 'Bestätigung';

  @override
  String get privacyPolicyAccept =>
      'Ich habe die Datenschutzerklärung gelesen und stimme ihr zu.';
}
