import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/hint.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class SettingsScreen extends StatelessWidget {
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction;

  const SettingsScreen({super.key, this.launchUrlFunction = launchUrl});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpenSenseMapBloc, OpenSenseMapState>(
      builder: (context, openSenseMapState) {
        final openSenseMapBloc = context.read<OpenSenseMapBloc>();
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final settingsBloc = context.read<SettingsBloc>();
            return Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.generalSettings),
              ),
              body: ListView(
                children: <Widget>[
                  _buildLoginLogoutSection(
                    context,
                    openSenseMapBloc,
                    openSenseMapState,
                  ),
                  _buildGeneralSettingsSection(
                      context, settingsBloc, settingsState),
                  _buildAccountManagementSection(context),
                  _buildOtherSection(context),
                  _buildHelpSection(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoginLogoutSection(
    BuildContext context,
    OpenSenseMapBloc openSenseMapBloc,
    OpenSenseMapState openSenseMapState,
  ) {
    final isAuthenticated = openSenseMapState.isAuthenticated;

    return _buildSettingsContainer(
      context,
      isAuthenticated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: openSenseMapBloc.userData,
            builder: (context, snapshot) {
              return _buildUserInfoRow(
                  context, isAuthenticated, snapshot.data, openSenseMapBloc);
            },
          ),
          const SizedBox(height: 16),
          _buildLoginLogoutButton(context, isAuthenticated, openSenseMapBloc),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer(BuildContext context, bool isAuthenticated,
      {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadiusSmall),
        color: isAuthenticated
            ? Theme.of(context).colorScheme.tertiary
            : loginRequiredColor,
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildUserInfoRow(BuildContext context, bool isAuthenticated,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
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

  Widget _buildAuthenticatedUserInfo(BuildContext context,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
    if (openSenseMapBloc.isAuthenticating) {
      return const CircularProgressIndicator();
    }

    if (userData == null) {
      return const CircularProgressIndicator();
    }

    return _buildUserDataDisplay(context, userData, openSenseMapBloc);
  }

  Widget _buildUserDataDisplay(BuildContext context,
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
    await showAppModalSheet(
      context: context,
      useRootNavigator: true,
      scaleBackground: true,
      builder: (context) => contentBuilder(context),
    );
  }

  Widget _buildLoginModalContent(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: const LoginScreen(),
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
    final isarService = context.read<TrackBloc>().isarService;
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
    BuildContext context,
    SettingsBloc settingsBloc,
    SettingsState settingsState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            context, AppLocalizations.of(context)!.settingsGeneral),
        ListTile(
          leading: const Icon(Icons.vibration),
          title:
              Text(AppLocalizations.of(context)!.settingsVibrateOnDisconnect),
          trailing: Switch(
            value: settingsState.vibrateOnDisconnect,
            onChanged: (value) {
              settingsBloc.toggleVibrateOnDisconnect(value);
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings),
          title: Text(AppLocalizations.of(context)!.generalPrivacyZones),
          onTap: () => context.push(AppRoutes.exclusionZones),
          trailing: Badge.count(
            count: settingsState.privacyZones.length,
            backgroundColor: Theme.of(context).iconTheme.color,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.trending_up_outlined),
          title: Text(AppLocalizations.of(context)!.trackStatistics),
          onTap: () => context.push(AppRoutes.trackStatistics),
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
