import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction;

  const SettingsScreen({super.key, this.launchUrlFunction = launchUrl});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.generalSettings),
      ),
      body: ListView(
        children: <Widget>[
          _buildGeneralSettingsSection(context, settingsBloc),
          _buildOtherSection(context),
          _buildHelpSection(context),
        ],
      ),
    );
  }

  // General Settings Section
  Widget _buildGeneralSettingsSection(
      BuildContext context, SettingsBloc settingsBloc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            context, AppLocalizations.of(context)!.settingsGeneral),
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
      ],
    );
  }

  // Other Section
  Widget _buildOtherSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            context, AppLocalizations.of(context)!.settingsOther),
        ListTile(
          leading: const Icon(Icons.info),
          title: Text(AppLocalizations.of(context)!.settingsAbout),
          subtitle: FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(AppLocalizations.of(context)!.settingsVersion(
                    '${snapshot.data!.version}+${snapshot.data!.buildNumber}'));
              } else {
                return Text(AppLocalizations.of(context)!.generalLoading);
              }
            },
          ),
        ),
        _buildUrlTile(
          context,
          icon: Icons.privacy_tip,
          title: AppLocalizations.of(context)!.settingsPrivacyPolicy,
          url: senseBoxBikePrivacyPolicyUrl,
        ),
      ],
    );
  }

  // Help Section
  Widget _buildHelpSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            context, AppLocalizations.of(context)!.settingsContact),
        _buildUrlTile(
          context,
          icon: Icons.contact_mail,
          title: AppLocalizations.of(context)!.settingsEmail,
          url: 'mailto:$contactEmail?subject=senseBox:bike%20App',
        ),
        _buildUrlTile(
          context,
          icon: Icons.bug_report,
          title: AppLocalizations.of(context)!.settingsGithub,
          url: gitHubNewIssueUrl,
        ),
      ],
    );
  }

  // Reusable Section Header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  // Reusable URL Tile
  Widget _buildUrlTile(BuildContext context,
      {required IconData icon, required String title, required String url}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        launchUrlFunction(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }
}
