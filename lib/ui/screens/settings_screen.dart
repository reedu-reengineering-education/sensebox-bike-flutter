import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/error_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/hint.dart';
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
          _buildAccountManagementSection(context),
          _buildOtherSection(context),
          _buildHelpSection(context),
        ],
      ),
    );
  }

  Widget _buildAccountManagementSection(BuildContext context) {
    final isarService = Provider.of<TrackBloc>(context).isarService;
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    bool isDeleting = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localizations.accountManagement),
            Center(
              child: ButtonWithLoader(
                isLoading: isDeleting,
                onPressed: isDeleting
                    ? null
                    : () async {
                        final confirmation = await showErrorDialog(context,
                            localizations.settingsDeleteAllDataConfirmation);

                        if (confirmation == true) {
                          setState(() {
                            isDeleting = true;
                          });

                          try {
                            await isarService.deleteAllData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    localizations.settingsDeleteAllDataSuccess),
                              ),
                            );
                          } catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    localizations.settingsDeleteAllDataError),
                              ),
                            );
                          } finally {
                            setState(() {
                              isDeleting = false;
                            });
                          }
                        }
                      },
                text: localizations.settingsDeleteAllData,
                width: 0.7,
              ),
            ),
            Hint(text: localizations.deleteAllHint),
          ],
        );
      },
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

  Widget _buildOtherSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localizations.settingsOther),
            ListTile(
              leading: const Icon(Icons.info),
              title: Text(localizations.settingsAbout),
              subtitle: FutureBuilder(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(localizations.settingsVersion(
                        '${snapshot.data!.version}+${snapshot.data!.buildNumber}'));
                  } else {
                    return Text(localizations.generalLoading);
                  }
                },
              ),
            ),
            _buildUrlTile(
              context,
              icon: Icons.privacy_tip,
              title: localizations.settingsPrivacyPolicy,
              url: senseBoxBikePrivacyPolicyUrl,
            )
          ],
        );
      },
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
          top: spacing * 3, bottom: spacing, left: spacing, right: spacing),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildUrlTile(BuildContext context,
      {required IconData icon, required String title, required String url}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () async {
        try {
          await launchUrlFunction(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        } catch (error, stack) {
          ErrorService.handleError(error, stack);
        }
      },
    );
  }
}
