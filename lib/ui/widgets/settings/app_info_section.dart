import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/changelog_modal.dart';
import 'package:sensebox_bike/ui/widgets/settings/settings_list_tile.dart';
import 'package:sensebox_bike/utils/storage_utils.dart';
import 'package:sensebox_bike/utils/url_launch_utils.dart';
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
  late final Future<String?> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersionLabel();
  }

  Future<String?> _loadVersionLabel() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        FutureBuilder<String?>(
          future: _versionFuture,
          builder: (context, snapshot) {
            final versionText = switch (snapshot.connectionState) {
              ConnectionState.none ||
              ConnectionState.waiting ||
              ConnectionState.active =>
                localizations.settingsVersion('...'),
              ConnectionState.done
                  when snapshot.hasError || snapshot.data == null =>
                localizations.settingsVersion('—'),
              ConnectionState.done =>
                localizations.settingsVersion(snapshot.data!),
            };

            return SettingsInfoTile(
              icon: Icons.info_outline,
              title: versionText,
              onTap: () => showChangelogModalForCurrentVersion(context),
            );
          },
        ),
        const _StorageUsageTile(),
        SettingsNavigationTile(
          icon: Icons.privacy_tip_outlined,
          title: localizations.settingsPrivacyPolicy,
          onTap: () => launchExternalUrl(
            senseBoxBikePrivacyPolicyUrl,
            launchUrlFunction: widget.launchUrlFunction,
          ),
        ),
      ],
    );
  }
}

class _StorageUsageTile extends StatefulWidget {
  const _StorageUsageTile();

  @override
  State<_StorageUsageTile> createState() => _StorageUsageTileState();
}

class _StorageUsageTileState extends State<_StorageUsageTile> {
  Future<AppStorageInfo?>? _storageFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _storageFuture = _loadStorageInfo();
      });
    });
  }

  Future<AppStorageInfo?> _loadStorageInfo() async {
    try {
      return await getAppStorageInfo();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final subtitleStyle = settingsInfoSubtitleStyle(context);

    return FutureBuilder<AppStorageInfo?>(
      future: _storageFuture,
      builder: (context, snapshot) {
        final subtitle = switch (snapshot.connectionState) {
          ConnectionState.none ||
          ConnectionState.waiting ||
          ConnectionState.active =>
            Text('...', style: subtitleStyle),
          ConnectionState.done when snapshot.hasError || snapshot.data == null =>
            Text('—', style: subtitleStyle),
          ConnectionState.done => Text(
              localizations.settingsStorageDetails(
                formatStorageSize(snapshot.data!.isarSize),
                formatStorageSize(snapshot.data!.totalAppDataSize),
              ),
              style: subtitleStyle,
            ),
        };

        return SettingsInfoTile(
          icon: Icons.storage,
          title: localizations.settingsStorageUsed,
          subtitle: subtitle,
        );
      },
    );
  }
}
