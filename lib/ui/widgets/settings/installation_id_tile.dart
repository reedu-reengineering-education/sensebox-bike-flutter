import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/installation_id_service.dart';
import 'package:sensebox_bike/ui/widgets/settings/settings_list_tile.dart';

class InstallationIdTile extends StatelessWidget {
  const InstallationIdTile({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final installationId = InstallationIdService.id;

    return SettingsCopyTile(
      icon: Icons.fingerprint,
      title: localizations.settingsInstallationId,
      value: installationId,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        await Clipboard.setData(ClipboardData(text: installationId));
        messenger.showSnackBar(
          SnackBar(content: Text(localizations.settingsInstallationIdCopied)),
        );
      },
    );
  }
}
