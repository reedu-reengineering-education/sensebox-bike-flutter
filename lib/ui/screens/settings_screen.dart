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
import 'package:sensebox_bike/services/isar_service.dart';

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
    final isAuthenticated = openSenseMapBloc.isAuthenticated;
    final userData = openSenseMapBloc.getUserData();

    return _buildSettingsContainer(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfoRow(
              context, isAuthenticated, userData, openSenseMapBloc),
          const SizedBox(height: 16),
          _buildLoginLogoutButton(context, isAuthenticated, openSenseMapBloc),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer(BuildContext context,
      {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        color: Theme.of(context).colorScheme.tertiary,
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildUserInfoRow(BuildContext context, bool isAuthenticated,
      Future<Map<String, dynamic>?> userData,
      OpenSenseMapBloc openSenseMapBloc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12,
      children: [
        _buildUserIcon(context),
        if (isAuthenticated)
          _buildAuthenticatedUserInfo(context, userData, openSenseMapBloc)
        else
          _buildUnauthenticatedUserInfo(context),
      ],
    );
  }

  Widget _buildUserIcon(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.onTertiaryContainer.withAlpha(50),
      ),
      padding: const EdgeInsets.all(6),
      child: Icon(
        Icons.account_circle,
        size: 28,
        color: Theme.of(context).colorScheme.onTertiaryContainer,
      ),
    );
  }

  Widget _buildAuthenticatedUserInfo(
      BuildContext context,
      Future<Map<String, dynamic>?> userData,
      OpenSenseMapBloc openSenseMapBloc) {
    if (openSenseMapBloc.isAuthenticating) {
      return const CircularProgressIndicator();
    }
    
    return FutureBuilder(
      future: userData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          if (snapshot.error.toString().contains('Not authenticated')) {
            return _buildUnauthenticatedUserInfo(context);
          }
          return const SizedBox.shrink();
        } else {
          return _buildUserDataDisplay(
              context, snapshot.data, openSenseMapBloc);
        }
      },
    );
  }

  Widget _buildUserDataDisplay(
      BuildContext context,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
    final user = userData?['data']?['me'];
    final email = user?['email'] ?? "No email";
    final name = user?['name'] ?? "John Doe";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          email,
          style: _getPrimaryTextStyle(context),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          name,
          style: _getSecondaryTextStyle(context),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildUnauthenticatedUserInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.openSenseMapLogin,
          style: _getPrimaryTextStyle(context),
        ),
        Text(
          AppLocalizations.of(context)!.openSenseMapLoginDescription,
          style: _getSecondaryTextStyle(context),
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildLoginLogoutButton(BuildContext context, bool isAuthenticated,
      OpenSenseMapBloc openSenseMapBloc) {
    return ButtonWithLoader(
      inverted: Theme.of(context).brightness == Brightness.light,
      isLoading: openSenseMapBloc.isAuthenticating,
      onPressed: openSenseMapBloc.isAuthenticating
          ? null
          : () => _handleLoginLogoutAction(
              context, isAuthenticated, openSenseMapBloc),
      text: isAuthenticated
          ? AppLocalizations.of(context)!.generalLogout
          : AppLocalizations.of(context)!.generalLogin,
      width: 1,
    );
  }

  Future<void> _handleLoginLogoutAction(BuildContext context,
      bool isAuthenticated, OpenSenseMapBloc openSenseMapBloc) async {
    if (isAuthenticated) {
      await openSenseMapBloc.logout();
    } else {
      await _showModalBottomSheet(context, _buildLoginModalContent);
    }
  }

  Future<void> _showModalBottomSheet(BuildContext context,
      Widget Function(BuildContext) contentBuilder) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => contentBuilder(context),
    );
  }

  Widget _buildLoginModalContent(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(borderRadius),
        ),
        child: const Padding(
          padding: EdgeInsets.only(top: 16),
          child: LoginScreen(),
        ),
      ),
    );
  }

  TextStyle _getPrimaryTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );
  }

  TextStyle _getSecondaryTextStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );
  }

  Widget _buildAccountManagementSection(BuildContext context) {
    final isarService = Provider.of<TrackBloc>(context).isarService;
    final localizations = AppLocalizations.of(context)!;

    return StatefulBuilder(
      builder: (context, setState) {
        bool isDeleting = false;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, localizations.accountManagement),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildActionButton(
                  context: context,
                  text: localizations.settingsDeleteAllData,
                  isLoading: isDeleting,
                  onPressed: () => _handleDeleteAllData(
                      context,
                      isarService,
                      localizations,
                      setState,
                      () => isDeleting = true,
                      () => isDeleting = false),
                ),
              ),
            ),
            Hint(text: localizations.deleteAllHint),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return ButtonWithLoader(
      isLoading: isLoading,
      onPressed: isLoading ? null : onPressed,
      text: text,
      width: 1,
    );
  }

  Future<void> _handleDeleteAllData(
    BuildContext context,
    IsarService isarService,
    AppLocalizations localizations,
    StateSetter setState,
    VoidCallback setLoading,
    VoidCallback clearLoading,
  ) async {
    final confirmation = await showCustomDialog(
      context: context,
      message: localizations.settingsDeleteAllDataConfirmation,
      type: DialogType.confirmation,
    );

    if (confirmation == true) {
      setLoading();
      setState(() {});

      try {
        await isarService.deleteAllData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.settingsDeleteAllDataSuccess),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.settingsDeleteAllDataError),
            ),
          );
        }
      } finally {
        clearLoading();
        setState(() {});
      }
    }
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
        StreamBuilder<bool>(
          stream: settingsBloc.directUploadModeStream,
          initialData: settingsBloc.directUploadMode,
          builder: (context, snapshot) {
            final isDirectUpload = snapshot.data ?? false;
            final uploadModeText = isDirectUpload
                ? AppLocalizations.of(context)!.settingsUploadModeDirect
                : AppLocalizations.of(context)!.settingsUploadModePostRide;

            return ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: Text(AppLocalizations.of(context)!.settingsUploadMode),
              subtitle: Text(
                AppLocalizations.of(context)!
                    .settingsUploadModeCurrent(uploadModeText),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              onTap: () => _showUploadModeDialog(context, settingsBloc),
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

  void _showUploadModeDialog(BuildContext context, SettingsBloc settingsBloc) {
    final currentMode = settingsBloc.directUploadMode;
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.settingsUploadMode),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      title: Text(localizations.settingsUploadModePostRide),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localizations.settingsUploadModePostRideTitle),
                          const SizedBox(height: 8),
                          Text(
                            localizations.settingsUploadModePostRideDescription,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                      value: false,
                      groupValue: currentMode,
                      onChanged: (bool? value) {
                        if (value != null) {
                          settingsBloc.toggleDirectUploadMode(value);
                          Navigator.of(context).pop();
                        }
                      },
                      isThreeLine: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    const SizedBox(height: 16),
                    RadioListTile<bool>(
                      title: Text(localizations.settingsUploadModeDirect),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localizations.settingsUploadModeDirectTitle),
                          const SizedBox(height: 8),
                          Text(
                            localizations.settingsUploadModeDirectDescription,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                      value: true,
                      groupValue: currentMode,
                      onChanged: (bool? value) {
                        if (value != null) {
                          settingsBloc.toggleDirectUploadMode(value);
                          Navigator.of(context).pop();
                        }
                      },
                      isThreeLine: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.generalCancel),
            ),
          ],
        );
      },
    );
  }
}
