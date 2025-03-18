import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle),
      ),
      body: ListView(
        children: <Widget>[
          // Settings Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.settingsGeneral,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          StreamBuilder<bool>(
            stream: settingsBloc.vibrateOnDisconnectStream,
            initialData: settingsBloc.vibrateOnDisconnect,
            builder: (context, snapshot) {
              return ListTile(
                leading: const Icon(Icons.vibration),
                title: Text(
                    AppLocalizations.of(context)!.settingsVibrateOnDisconnect),
                trailing: Switch(
                  value: snapshot.data ?? false,
                  onChanged: (value) {
                    settingsBloc.toggleVibrateOnDisconnect(value);
                  },
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: Text(AppLocalizations.of(context)!.generalPrivacyZones),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExclusionZonesScreen()),
            ),
            trailing: Badge.count(
              count: settingsBloc.privacyZones.length,
              backgroundColor: Theme.of(context).iconTheme.color,
            ),
          ),

          // Other Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.settingsOther,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(AppLocalizations.of(context)!.settingsAbout),
            subtitle: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    AppLocalizations.of(context)!.settingsVersion(
                      '${snapshot.data!.version}+${snapshot.data!.buildNumber}'));
                } else {
                  return Text(AppLocalizations.of(context)!.generalLoading);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(AppLocalizations.of(context)!.settingsPrivacyPolicy),
            onTap: () {
              launchUrl(Uri.parse(
                  'https://sensebox.de/sensebox-bike-privacy-policy'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: Text(AppLocalizations.of(context)!.settingsContact),
            onTap: () {
              launchUrl(Uri.parse(
                  'mailto:kontakt@reedu.de?subject=senseBox:bike%20App'));
            },
          ),
        ],
      ),
    );
  }
}
