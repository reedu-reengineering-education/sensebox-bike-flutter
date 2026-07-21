import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/utils/storage_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfoSection extends StatefulWidget {
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction;

  const AppInfoSection({
    super.key,
    this.launchUrlFunction = launchUrl,
  });

  @override
  State<AppInfoSection> createState() => _AppInfoSectionState();
}

class _AppInfoSectionState extends State<AppInfoSection> {
  late final Future<_AppInfoData> _appInfoFuture;

  @override
  void initState() {
    super.initState();
    _appInfoFuture = _loadAppInfo();
  }

  Future<_AppInfoData> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    AppStorageInfo? storageInfo;
    try {
      storageInfo = await getAppStorageInfo();
    } catch (_) {
      storageInfo = null;
    }

    return _AppInfoData(
      versionLabel:
          '${packageInfo.version} (${packageInfo.buildNumber})',
      storageInfo: storageInfo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return FutureBuilder<_AppInfoData>(
      future: _appInfoFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final versionText = data != null
            ? localizations.settingsVersion(data.versionLabel)
            : localizations.settingsVersion('...');
        final storageSubtitle = _buildStorageSubtitle(context, data?.storageInfo);

        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(versionText),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: Text(localizations.settingsStorageUsed),
              subtitle: storageSubtitle,
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(localizations.settingsPrivacyPolicy),
              onTap: () async {
                try {
                  await widget.launchUrlFunction(
                    Uri.parse(senseBoxBikePrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (error, stack) {
                  ErrorService.handleError(error, stack);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget? _buildStorageSubtitle(
    BuildContext context,
    AppStorageInfo? storageInfo,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        );

    if (storageInfo == null) {
      return Text('—', style: subtitleStyle);
    }

    return Text(
      localizations.settingsStorageDetails(
        formatStorageSize(storageInfo.isarSize),
        formatStorageSize(storageInfo.totalAppDataSize),
      ),
      style: subtitleStyle,
    );
  }
}

class _AppInfoData {
  final String versionLabel;
  final AppStorageInfo? storageInfo;

  const _AppInfoData({
    required this.versionLabel,
    required this.storageInfo,
  });
}
