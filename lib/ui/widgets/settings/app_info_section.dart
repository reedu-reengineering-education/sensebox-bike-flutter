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
  late final Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = _loadVersionLabel();
  }

  Future<String> _loadVersionLabel() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      children: [
        FutureBuilder<String>(
          future: _versionFuture,
          builder: (context, snapshot) {
            final versionLabel = snapshot.data;
            final versionText = versionLabel != null
                ? localizations.settingsVersion(versionLabel)
                : localizations.settingsVersion('...');

            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(versionText),
            );
          },
        ),
        const _StorageUsageTile(),
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
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w500,
        );

    return FutureBuilder<AppStorageInfo?>(
      future: _storageFuture,
      builder: (context, snapshot) {
        final subtitle = switch (snapshot.connectionState) {
          ConnectionState.none => Text('...', style: subtitleStyle),
          ConnectionState.waiting => Text('...', style: subtitleStyle),
          ConnectionState.active => Text('...', style: subtitleStyle),
          ConnectionState.done when snapshot.data != null => Text(
              localizations.settingsStorageDetails(
                formatStorageSize(snapshot.data!.isarSize),
                formatStorageSize(snapshot.data!.totalAppDataSize),
              ),
              style: subtitleStyle,
            ),
          ConnectionState.done => Text('—', style: subtitleStyle),
        };

        return ListTile(
          leading: const Icon(Icons.storage),
          title: Text(localizations.settingsStorageUsed),
          subtitle: subtitle,
        );
      },
    );
  }
}
