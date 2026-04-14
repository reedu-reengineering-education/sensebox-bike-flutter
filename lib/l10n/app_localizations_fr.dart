// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsApiUrlLoadError =>
      'Impossible de charger les URLs de service disponibles. L\'URL par défaut sera utilisée pour l\'envoi des données. Pour en choisir une autre, veuillez vérifier votre connexion internet et rouvrir cette fenêtre pour recharger les URLs de service.';

  @override
  String settingsApiUrlLoadErrorWithMessage(String error) {
    return 'Impossible de charger les URLs de service disponibles. L\'URL par défaut sera utilisée pour l\'envoi des données. Erreur : $error\nPour en choisir une autre, veuillez vérifier votre connexion internet et rouvrir cette fenêtre pour recharger les URLs de service.';
  }

  @override
  String get settingsKnowledgeBase => 'Base de connaissances';

  @override
  String get uploadBlockNotAuthenticated =>
      'Le trajet actuel n\'a pas été téléversé automatiquement. Vous pouvez toujours l\'envoyer sur openSenseMap depuis la page d\'aperçu des parcours.\n\nPour téléverser votre trajet, veuillez vous connecter ou créer un compte dans les paramètres.';

  @override
  String get uploadBlockNoBox =>
      'Le trajet actuel n\'a pas été téléversé automatiquement. Vous pouvez toujours l\'envoyer sur openSenseMap depuis la page d\'aperçu des parcours.\n\nPour téléverser votre trajet, veuillez sélectionner ou créer une senseBox sur la page d\'accueil.';

  @override
  String get createBoxAddCustomTag =>
      'Ajouter une étiquette de groupe personnalisée';

  @override
  String get createBoxCustomTag => 'Étiquette de groupe personnalisée';

  @override
  String get createBoxCustomTagHelper =>
      'Vous pouvez séparer les étiquettes par des virgules';

  @override
  String get generalLoading => 'Chargement...';

  @override
  String get generalError => 'Erreur';

  @override
  String generalErrorWithDescription(String error) {
    return 'Erreur : $error';
  }

  @override
  String get generalCancel => 'Annuler';

  @override
  String get generalCreate => 'Créer';

  @override
  String get generalOk => 'OK';

  @override
  String get generalSave => 'Enregistrer';

  @override
  String get generalDelete => 'Supprimer';

  @override
  String get generalEdit => 'Modifier';

  @override
  String get generalAdd => 'Ajouter';

  @override
  String get generalClose => 'Fermer';

  @override
  String get reloadConfiguration => 'Recharger la configuration';

  @override
  String get generalUpload => 'Téléverser';

  @override
  String get generalPrivacyZones => 'Zones de confidentialité';

  @override
  String get generalSettings => 'Paramètres';

  @override
  String get generalShare => 'Partager';

  @override
  String generalTrackDuration(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String generalTrackDurationShort(String hours, String minutes) {
    return '$hours:$minutes h';
  }

  @override
  String generalTrackDistance(String distance) {
    return '$distance km';
  }

  @override
  String get generalExport => 'Exporter';

  @override
  String get generalLogin => 'Connexion';

  @override
  String get generalLoginOrRegister => 'Connexion ou inscription';

  @override
  String get generalLogout => 'Déconnexion';

  @override
  String get generalRegister => 'S’inscrire';

  @override
  String get generalProceed => 'Continuer';

  @override
  String get homeBottomBarHome => 'Accueil';

  @override
  String get homeBottomBarTracks => 'Parcours';

  @override
  String tracksAppBarSumTracks(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcours',
      one: '1 parcours',
      zero: 'Aucun parcours',
    );
    return '$_temp0';
  }

  @override
  String get tracksNoTracks => 'Aucun parcours disponible';

  @override
  String get tracksTrackDeleted => 'Parcours supprimé';

  @override
  String get openSenseMapLogin => 'Se connecter avec openSenseMap';

  @override
  String get openSenseMapLoginDescription =>
      'Connectez-vous pour partager vos données.';

  @override
  String get openSenseMapLogout => 'Déconnexion';

  @override
  String get openSenseMapEmail => 'E-mail';

  @override
  String get openSenseMapPassword => 'Mot de passe';

  @override
  String get openSenseMapEmailErrorEmpty => 'L’e-mail ne doit pas être vide';

  @override
  String get openSenseMapEmailErrorInvalid => 'Adresse e-mail invalide';

  @override
  String get openSenseMapPasswordErrorEmpty =>
      'Le mot de passe ne doit pas être vide';

  @override
  String get openSenseMapLoginFailed => 'Échec de la connexion';

  @override
  String get openSenseMapRegisterName => 'Nom d’utilisateur';

  @override
  String get openSenseMapRegisterNameErrorEmpty =>
      'Le nom d’utilisateur ne doit pas être vide';

  @override
  String get openSenseMapRegisterPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get openSenseMapRegisterPasswordConfirmErrorEmpty =>
      'La confirmation du mot de passe ne doit pas être vide';

  @override
  String get openSenseMapRegisterPasswordErrorMismatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get openSenseMapRegisterPasswordErrorCharacters =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get openSenseMapRegisterFailed => 'Échec de l’inscription';

  @override
  String get openSenesMapRegisterAcceptTermsPrefix => 'J’accepte la';

  @override
  String get openSenseMapRegisterAcceptTermsPrivacy =>
      'politique de confidentialité';

  @override
  String get openSenseMapRegisterAcceptTermsError =>
      'Vous devez accepter la politique de confidentialité';

  @override
  String get connectionButtonConnect => 'Connecter';

  @override
  String get connectionButtonDisconnect => 'Déconnecter';

  @override
  String get connectionButtonConnecting => 'Connexion...';

  @override
  String get connectionButtonReconnecting => 'Reconnexion...';

  @override
  String get connectionButtonStart => 'Démarrer';

  @override
  String get connectionButtonStop => 'Arrêter';

  @override
  String get bleDeviceSelectTitle => 'Touchez pour connecter';

  @override
  String get noBleDevicesFound =>
      'Aucune senseBox trouvée. Assurez-vous que votre senseBox est chargée, touchez en dehors de cette fenêtre et réessayez.';

  @override
  String get selectOrCreateBox => 'Sélectionner ou créer une senseBox:bike';

  @override
  String get createBoxTitle => 'Créer une senseBox:bike';

  @override
  String get createBoxModel => 'Modèle';

  @override
  String get createBoxModelErrorEmpty => 'Veuillez sélectionner un modèle';

  @override
  String get createBoxName => 'Nom';

  @override
  String get createBoxNameError =>
      'Le nom doit comporter entre 2 et 50 caractères';

  @override
  String get createBoxGeolocationCurrentPosition =>
      'Votre position actuelle sera utilisée';

  @override
  String get openSenseMapBoxSelectionNoBoxes =>
      'Aucune senseBox disponible ou configuration non chargée';

  @override
  String get openSenseMapBoxSelectionCreateHint =>
      'Créez-en une avec le bouton \'+\'';

  @override
  String get openSenseMapBoxSelectionUnnamedBox => 'senseBox sans nom';

  @override
  String get openSenseMapBoxSelectionIncompatible =>
      'Non compatible avec senseBox:bike';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsOther => 'Autre';

  @override
  String get settingsVibrateOnDisconnect => 'Vibrer lors de la déconnexion';

  @override
  String get settingsUploadMode => 'Mode de téléversement';

  @override
  String get settingsUploadModeDirect => 'Téléversement direct (Bêta)';

  @override
  String get settingsUploadModePostRide => 'Téléversement après trajet';

  @override
  String get settingsUploadModeDescription =>
      'Choisissez quand téléverser vos données pendant l’enregistrement';

  @override
  String settingsUploadModeCurrent(String mode) {
    return 'Actuel : $mode';
  }

  @override
  String get settingsUploadModePostRideTitle =>
      'Téléverser les données après l’arrêt de l’enregistrement';

  @override
  String get settingsUploadModePostRideDescription =>
      '• Les données sont stockées localement pendant l’enregistrement\n• Le téléversement se fait en une seule fois à la fin\n• Plus fiable et stable\n• Utilise moins de batterie pendant l’enregistrement';

  @override
  String get settingsUploadModeDirectTitle =>
      'Téléverser les données en temps réel pendant l’enregistrement (expérimental)';

  @override
  String get settingsUploadModeDirectDescription =>
      '• Les données sont téléversées immédiatement dès leur collecte\n• Partage des données en temps réel (expérimental)\n• Nécessite une connexion internet stable\n• Peut utiliser plus de batterie pendant l’enregistrement';

  @override
  String get settingsApiUrl => 'URL du service';

  @override
  String get settingsApiUrlHelper =>
      'Saisir le point de terminaison de l\'API pour les téléversements de données';

  @override
  String get settingsApiUrlError =>
      'Veuillez saisir une URL valide (par ex., https://api.opensensemap.org)';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String settingsVersion(String versionNumber) {
    return 'Version : $versionNumber';
  }

  @override
  String get settingsContact => 'Aide ou retour ?';

  @override
  String get settingsEmail => 'E-mail';

  @override
  String get settingsGithub => 'Ticket GitHub';

  @override
  String get privacyZonesStart =>
      'Touchez la carte pour commencer à dessiner une zone. Touchez la coche pour terminer.';

  @override
  String get privacyZonesDelete =>
      'Touchez une zone pour la supprimer. Touchez la coche pour terminer.';

  @override
  String get trackDetailsPermissionsError =>
      'Permission refusée pour enregistrer le fichier dans le stockage externe.';

  @override
  String get trackDetailsFileSaved =>
      'Fichier CSV enregistré dans le dossier Téléchargements.';

  @override
  String get trackDetailsExport => 'Export CSV des données du parcours.';

  @override
  String get trackDetailsLoadingError =>
      'Erreur lors du chargement du parcours.';

  @override
  String get trackDetailsNoTrackData => 'Aucun parcours disponible.';

  @override
  String get trackDelete => 'Supprimer le parcours';

  @override
  String get trackDeleteConfirmation =>
      'Êtes-vous sûr de vouloir supprimer ce parcours ?';

  @override
  String get sensorTemperature => 'Température';

  @override
  String get sensorHumidity => 'Humidité relative';

  @override
  String get sensorFinedustPM10 => 'Particules fines PM10';

  @override
  String get sensorFinedustPM4 => 'Particules fines PM4';

  @override
  String get sensorFinedustPM25 => 'Particules fines PM2.5';

  @override
  String get sensorFinedustPM1 => 'Particules fines PM1';

  @override
  String get sensorDistance => 'Distance gauche';

  @override
  String get sensorDistanceRight => 'Distance droite';

  @override
  String get sensorOvertaking => 'Prédiction de dépassement';

  @override
  String get sensorOvertakingShort => 'Dépassement';

  @override
  String get sensorSurface => 'Surface';

  @override
  String get sensorSurfaceAsphalt => 'Surface asphalte';

  @override
  String get sensorSurfaceAsphaltShort => 'Asphalte';

  @override
  String get sensorSurfaceSett => 'Surface pavés';

  @override
  String get sensorSurfaceSettShort => 'Pavés';

  @override
  String get sensorSurfaceCompacted => 'Surface compactée';

  @override
  String get sensorSurfaceCompactedShort => 'Compactée';

  @override
  String get sensorSurfacePaving => 'Surface pavage';

  @override
  String get sensorSurfacePavingShort => 'Pavage';

  @override
  String get sensorSurfaceStanding => 'À l’arrêt';

  @override
  String get sensorSurfaceAnomaly => 'Anomalie de surface';

  @override
  String get sensorSpeed => 'Vitesse';

  @override
  String get sensorAccelerationX => 'Accélération X';

  @override
  String get sensorAccelerationY => 'Accélération Y';

  @override
  String get sensorAccelerationZ => 'Accélération Z';

  @override
  String get sensorGPSLat => 'Latitude GPS';

  @override
  String get sensorGPSLong => 'Longitude GPS';

  @override
  String get sensorGPSSpeed => 'Vitesse GPS';

  @override
  String get sensorGPSError => 'Pas de signal GPS';

  @override
  String get sensorAcceleration => 'Accélération';

  @override
  String get sensorFinedust => 'Particules fines';

  @override
  String get sensorDistanceShort => 'Distance';

  @override
  String get campaignLoadError =>
      'Échec du chargement de la liste des campagnes.';

  @override
  String get boxConfigurationLoadError =>
      'Échec du chargement des configurations de box.';

  @override
  String get selectCampaign => 'Sélectionner une campagne';

  @override
  String get noCampaignsAvailable => 'Aucune campagne disponible';

  @override
  String get loginScreenTitle => 'Compte openSenseMap';

  @override
  String get connectionButtonEnableBluetooth => 'Activer le Bluetooth';

  @override
  String get errorNoLocationAccess =>
      'Les services de localisation sont désactivés ou l’accès est refusé. Pour enregistrer des parcours, veuillez activer la localisation et autoriser l’application à accéder à votre position dans les paramètres du téléphone.';

  @override
  String get errorNoScanAccess =>
      'Pour vous connecter à la senseBox, autorisez l’application à rechercher des appareils à proximité dans les paramètres du téléphone.';

  @override
  String get errorNoSenseBoxSelected =>
      'Pour permettre le téléversement des données des capteurs vers le cloud, veuillez vous connecter à votre compte openSenseMap et sélectionner la box.';

  @override
  String get trackUploadLoginSelectHint =>
      'Connectez-vous et sélectionnez une senseBox pour téléverser.';

  @override
  String get uploadRequirementsTitle => 'Téléversement indisponible';

  @override
  String get uploadPostRideRequirementsMessage =>
      'Pour téléverser votre trajet, connectez-vous à votre compte openSenseMap, sélectionnez une senseBox, puis ouvrez l’aperçu du parcours et touchez le bouton de téléversement en haut à droite.';

  @override
  String get loginRequiredMessage =>
      'Veuillez vous connecter pour partager les données des capteurs';

  @override
  String get errorExportDirectoryAccess =>
      'Erreur lors de l’accès au dossier d’exportation. Assurez-vous que l’application dispose des permissions de stockage.';

  @override
  String get errorLoginFailed =>
      'Échec de la connexion. Veuillez vérifier vos identifiants et réessayer plus tard.';

  @override
  String get errorRegistrationFailed =>
      'Échec de l’inscription. Veuillez vérifier vos identifiants et réessayer plus tard.';

  @override
  String get errorReasonPrefix => 'Raison :';

  @override
  String get errorBleConnectionFailed =>
      'La connexion à la senseBox a été perdue. Assurez-vous que le Bluetooth est activé et que la senseBox est allumée.';

  @override
  String get errorUploadFailed =>
      'Échec du téléversement des données. Veuillez vérifier votre connexion internet et réessayer.';

  @override
  String get errorDirectUploadFailed =>
      'L’envoi en temps réel a échoué en raison de problèmes de connectivité. Ne vous inquiétez pas : vos données ont été enregistrées localement. Après avoir arrêté l’enregistrement, vous pouvez téléverser la trace manuellement depuis l’écran d’aperçu des parcours.';

  @override
  String get errorPermanentAuthentication =>
      'Échec permanent de l’authentification. Veuillez vous connecter pour téléverser les données.';

  @override
  String get selectCsvFormat => 'Sélectionner le format CSV';

  @override
  String get regularCsv => 'CSV standard';

  @override
  String get openSenseMapCsv => 'CSV openSenseMap';

  @override
  String get settingsDeleteAllData => 'Supprimer toutes les données';

  @override
  String get settingsDeleteAllDataConfirmation =>
      'Voulez-vous vraiment supprimer toutes les données ? Cette action est irréversible.';

  @override
  String get settingsDeleteAllDataSuccess =>
      'Toutes les données ont été supprimées avec succès.';

  @override
  String get settingsDeleteAllDataError =>
      'Échec de la suppression de toutes les données. Veuillez réessayer.';

  @override
  String get accountManagement => 'Gestion du compte';

  @override
  String get deleteAllHint =>
      'Cela supprimera tous vos parcours de l’application.';

  @override
  String get generalConfirmation => 'Confirmation';

  @override
  String get privacyPolicyAccept =>
      'J’ai lu et j’accepte la politique de confidentialité.';

  @override
  String get trackNoGeolocations =>
      'Aucune géolocalisation disponible pour ce parcours.';

  @override
  String get tracksAppBarTitle => 'Vos parcours';

  @override
  String get loadMore => 'Charger plus';

  @override
  String get tracksStatisticsTitle => 'Statistiques des parcours';

  @override
  String get tracksStatisticsTotalData => 'Données totales';

  @override
  String get tracksStatisticsThisWeek => 'Cette semaine';

  @override
  String get tracksStatisticsRidesInfo => 'trajets effectués';

  @override
  String get tracksStatisticsDistanceInfo => 'distance parcourue';

  @override
  String get tracksStatisticsTimeInfo => 'temps passé sur la route';

  @override
  String get trackStatistics => 'Statistiques du parcours';

  @override
  String get uploadProgressTitle => 'Progression du téléversement';

  @override
  String get uploadProgressPreparing => 'Préparation du téléversement...';

  @override
  String get uploadProgressUploading =>
      'Téléversement des données du parcours...';

  @override
  String get uploadProgressInfo =>
      'Ne fermez pas l’application pendant le téléversement. Cela peut prendre un certain temps selon la longueur du parcours.\n\nSi vous souhaitez téléverser plus tard, vous pouvez le faire depuis l’écran d’aperçu des parcours.';

  @override
  String get uploadProgressRetrying => 'Nouvelle tentative de téléversement...';

  @override
  String get uploadProgressCompleted => 'Téléversement terminé avec succès';

  @override
  String get uploadProgressFailed => 'Échec du téléversement';

  @override
  String get uploadProgressAuthenticationFailed => 'Authentification requise';

  @override
  String uploadProgressChunks(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total segments',
      one: '1 segment',
      zero: '0 segments',
    );
    return '$completed sur $_temp0 téléversés';
  }

  @override
  String uploadProgressPercentage(int percentage) {
    return '$percentage% terminé';
  }

  @override
  String get uploadProgressAuthenticationError =>
      'Veuillez vous connecter pour téléverser les données.';

  @override
  String get uploadProgressNetworkError =>
      'Échec de la connexion réseau. Veuillez vérifier votre connexion internet et réessayer.';

  @override
  String get uploadProgressGenericError =>
      'Échec du téléversement. Veuillez réessayer.';

  @override
  String get uploadConfirmTitle => 'Téléverser les données du parcours';

  @override
  String get uploadConfirmMessage =>
      'Voulez-vous téléverser les données de votre parcours maintenant ?';

  @override
  String get uploadConfirmUploadNow => 'Téléverser';

  @override
  String get trackStatusUploaded => 'Téléversé';

  @override
  String trackStatusUploadedAt(String date) {
    return 'Téléversé le $date';
  }

  @override
  String get trackStatusNotUploaded => 'Non téléversé';

  @override
  String get trackStatusUploadFailed => 'Échec du téléversement';

  @override
  String trackStatusUploadFailedAt(Object date) {
    return 'Échec le $date';
  }

  @override
  String get trackDirectUploadInfo =>
      'Ces données de parcours ont été téléversées en temps réel pendant votre trajet. Si vous souhaitez les téléverser à nouveau, vous pouvez utiliser le bouton de téléversement ci-dessus.';

  @override
  String get trackUploadAttempts => 'Tentatives de téléversement';

  @override
  String get trackLastAttempt => 'Dernière tentative';

  @override
  String get trackStatus => 'Statut';

  @override
  String get trackDirectUploadAuthFailed =>
      'Ce parcours n’a pas pu être téléversé en temps réel car vous n’étiez pas connecté. Veuillez vous connecter et réessayer le téléversement.';

  @override
  String get trackFilterAll => 'Tous';

  @override
  String get trackFilterUnuploaded => 'Non téléversé';

  @override
  String get trackUploadRetryFailed =>
      'La nouvelle tentative de téléversement a échoué. Veuillez réessayer.';

  @override
  String get errorTrackNoGeolocations =>
      'Le parcours ne contient pas de données de géolocalisation et ne peut pas être téléversé.';

  @override
  String get openSenseMapInfoText =>
      'Vos données senseBox:bike seront partagées sur openSenseMap, contribuant à la science citoyenne et à la surveillance environnementale.';

  @override
  String get openSenseMapInfoLink => 'Visiter openSenseMap.org';

  @override
  String get loginForgotPasswordInfo =>
      'Si vous avez oublié votre mot de passe, veuillez aller sur openSenseMap, cliquer sur \"Connexion\" puis sur \"Mot de passe oublié ?\".';
}
