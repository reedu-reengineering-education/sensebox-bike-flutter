import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/sensebox.dart';

Uri buildSupportEmailUri(
  AppLocalizations localizations, {
  required String installationId,
  String? appVersion,
  String? storageDetails,
  SenseBox? senseBox,
}) {
  final campaignTags = [
    for (final tag in senseBox?.grouptag ?? const <String>[])
      if (tag != bikeGrouptag) tag,
  ];
  final details = [
    '${localizations.settingsInstallationId}: $installationId',
    if (appVersion != null) localizations.settingsVersion(appVersion),
    if (storageDetails != null) storageDetails,
    if (senseBox?.name != null) localizations.supportEmailBox(senseBox!.name!),
    if (campaignTags.isNotEmpty)
      localizations.supportEmailCampaign(campaignTags.join(', ')),
  ];
  final body = [
    localizations.supportEmailIntro,
    '',
    '',
    '',
    '---',
    localizations.supportEmailDetails,
    ...details,
  ].join('\n');

  return Uri.parse(
    'mailto:$contactEmail'
    '?subject=${Uri.encodeComponent(localizations.supportEmailSubject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
}
