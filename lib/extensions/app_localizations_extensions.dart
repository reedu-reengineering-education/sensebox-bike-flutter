import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension AppLocalizationsExtensions on AppLocalizations {
  String getLocation(String tag) {
    switch (tag) {
      case 'wiesbaden':
        return locationWiesbaden; 
      case 'muenster':
        return locationMuenster; 
      case 'arnsberg':
        return locationArnsberg; 
      default:
        return locationOther; // Fallback to the raw tag
    }
  }
}