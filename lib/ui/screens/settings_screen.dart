import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/screens/track_statistics_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/hint.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction;

  const SettingsScreen({super.key, this.launchUrlFunction = launchUrl});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);
    final OpenSenseMapBloc openSenseMapBloc =
        Provider.of<OpenSenseMapBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.generalSettings),
      ),
      body: ListView(
        children: <Widget>[
          _buildLoginLogoutSection(context, openSenseMapBloc),
          _buildGeneralSettingsSection(context, settingsBloc),
          _buildAccountManagementSection(context),
          _buildOtherSection(context),
          _buildHelpSection(context),
        ],
      ),
    );
  }

  Widget _buildLoginLogoutSection(
      BuildContext context, OpenSenseMapBloc openSenseMapBloc) {
    bool isAuthenticated = openSenseMapBloc.isAuthenticated;

    Future<Map<String, dynamic>?> userData = openSenseMapBloc.userData;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        color: Theme.of(context).colorScheme.tertiary,
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .onTertiaryContainer
                      .withAlpha(50),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.account_circle,
                  size: 28,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              if (isAuthenticated)
                FutureBuilder(
                    future: userData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text("Error: ${snapshot.error}");
                      } else {
                        final userData = snapshot.data;

                        final user = userData?['data']?['me'];

                        final email = user['email'];
                        final name = user['name'];

                        if (user == null) {
                          return Text(
                            "No user data available",
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              email ?? "No email",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer,
                              ),
                            ),
                            Text(
                              name ?? "John Doe",
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer,
                              ),
                            ),
                          ],
                        );
                      }
                    })
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      "openSenseMap Account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      "Sign in to share your data",
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                )
            ],
          ),
          const SizedBox(height: 16),
          ButtonWithLoader(
            inverted: true,
            isLoading: false,
            onPressed: () async {
              if (isAuthenticated) {
                await openSenseMapBloc.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Successfully logged out")),
                );
              } else {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height * 0.9,
                      // border radius top
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(borderRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: LoginScreen(),
                        ),
                      ),
                    );
                  },
                );
              }
            },
            text: isAuthenticated ? "Logout" : "Sign in",
            width: 1,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAccountManagementSection(BuildContext context) {
    final isarService = Provider.of<TrackBloc>(context).isarService;
    final localizations = AppLocalizations.of(context)!;
    bool isDeleting = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localizations.accountManagement),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ButtonWithLoader(
                  isLoading: isDeleting,
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final confirmation = await showCustomDialog(
                            context: context,
                            message:
                                localizations.settingsDeleteAllDataConfirmation,
                            type: DialogType.confirmation,
                          );

                          if (confirmation == true) {
                            setState(() {
                              isDeleting = true;
                            });

                            try {
                              await isarService.deleteAllData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(localizations
                                      .settingsDeleteAllDataSuccess),
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
                  width: 1,
                ),
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
    final isarService = Provider.of<TrackBloc>(context).isarService;
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
        ListTile(
          leading: const Icon(Icons.trending_up_outlined),
          title: Text(AppLocalizations.of(context)!.trackStatistics),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    TrackStatisticsScreen(isarService: isarService)),
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
