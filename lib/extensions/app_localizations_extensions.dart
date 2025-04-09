import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension AppLocalizationsExtensions on AppLocalizations {
  String getLocation(String tag) {
    switch (tag) {
      case 'other':
        return locationOther; 
      case 'wiesbaden':
        return locationWiesbaden; 
      case 'muenster':
        return locationMuenster; 
      case 'arnsberg':
        return locationArnsberg; 
      default:
        return tag; // Fallback to the raw tag
    }
  }
}