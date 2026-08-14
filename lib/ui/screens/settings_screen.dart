import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/api_url_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/hint.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/ui/widgets/settings/app_info_section.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class SettingsScreen extends StatefulWidget {
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction;

  const SettingsScreen({super.key, this.launchUrlFunction = launchUrl});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenSenseMapBloc>(
      builder: (context, openSenseMapState, _) {
        final openSenseMapBloc = context.read<OpenSenseMapBloc>();
        return Consumer<SettingsBloc>(
          builder: (context, settingsState, _) {
            final settingsBloc = context.read<SettingsBloc>();
            final configurationBloc = context.read<ConfigurationBloc>();

            if (context.isTablet) {
              return _buildTabletLayout(
                context,
                openSenseMapBloc,
                openSenseMapState,
                settingsBloc,
                settingsState,
                configurationBloc,
              );
            }

            return ScreenWrapper(
              title: AppLocalizations.of(context)!.generalSettings,
              child: ListView(
                children: <Widget>[
                  _buildLoginLogoutSection(
                    context,
                    openSenseMapBloc,
                    openSenseMapState,
                  ),
                  _buildOtherSection(context),
                  _buildGeneralSettingsSection(
                    context,
                    settingsBloc,
                    settingsState,
                    configurationBloc,
                  ),
                  _buildAccountManagementSection(context),
                  _buildHelpSection(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Tablet two-pane layout ──────────────────────────────────────────────────

  Widget _buildTabletLayout(
    BuildContext context,
    OpenSenseMapBloc openSenseMapBloc,
    OpenSenseMapBloc openSenseMapState,
    SettingsBloc settingsBloc,
    SettingsBloc settingsState,
    ConfigurationBloc configurationBloc,
  ) {
    final localizations = AppLocalizations.of(context)!;

    final sections = [
      (Icons.tune, localizations.settingsGeneral),
      (Icons.info_outline, localizations.settingsAbout),
      (Icons.help_outline, localizations.settingsContact),
    ];

    final sectionContent = [
      ListView(children: [
        _buildGeneralSettingsSection(
            context, settingsBloc, settingsState, configurationBloc),
        _buildAccountManagementSection(context),
      ]),
      ListView(children: [_buildOtherSection(context)]),
      ListView(children: [_buildHelpSection(context)]),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.generalSettings,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsSidebar(
            selectedIndex: _selectedIndex,
            sections: sections,
            onSelected: (i) => setState(() => _selectedIndex = i),
            openSenseMapBloc: openSenseMapBloc,
            openSenseMapState: openSenseMapState,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: sectionContent,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared section builders ─────────────────────────────────────────────────

  Widget _buildLoginLogoutSection(
    BuildContext context,
    OpenSenseMapBloc openSenseMapBloc,
    OpenSenseMapBloc openSenseMapState,
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
          : AppLocalizations.of(context)!.generalLoginOrRegister,
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
    SettingsBloc settingsState,
    ConfigurationBloc configurationBloc,
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
        _buildApiUrlSection(context, settingsBloc, configurationBloc),
      ],
    );
  }

  Widget _buildApiUrlSection(
    BuildContext context,
    SettingsBloc settingsBloc,
    ConfigurationBloc configurationBloc,
  ) {
    return ListenableBuilder(
      listenable: configurationBloc,
      builder: (context, _) {
        final controller = TextEditingController(text: settingsBloc.apiUrl);

        return ListTile(
          leading: const Icon(Icons.settings_ethernet_outlined),
          title: Text(AppLocalizations.of(context)!.settingsApiUrl),
          subtitle: Text(
            settingsBloc.apiUrl,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          onTap: () async {
            if (configurationBloc.apiUrls == null &&
                !configurationBloc.isLoadingApiUrls) {
              await configurationBloc.loadApiUrls();
            }
            if (!context.mounted) return;
            _showApiUrlDialog(
              context,
              settingsBloc,
              controller,
              apiUrls: configurationBloc.apiUrls,
              isLoading: configurationBloc.isLoadingApiUrls,
              error: configurationBloc.apiUrlsError,
            );
          },
        );
      },
    );
  }

  void _showApiUrlDialog(
    BuildContext context,
    SettingsBloc settingsBloc,
    TextEditingController controller, {
    List<String>? apiUrls,
    bool isLoading = false,
    String? error,
  }) {
    showAppDialog(
      context: context,
      builder: (context) => ApiUrlDialog(
        settingsBloc: settingsBloc,
        controller: controller,
        apiUrls: apiUrls,
        isLoading: isLoading,
        error: error,
      ),
    );
  }

  Widget _buildOtherSection(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, localizations.settingsAbout),
        AppInfoSection(launchUrlFunction: widget.launchUrlFunction),
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
          icon: Icons.menu_book,
          title: AppLocalizations.of(context)!.settingsKnowledgeBase,
          url: knowledgeBaseUrl,
        ),
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
          await widget.launchUrlFunction(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        } catch (error, stack) {
          ErrorService.handleError(error, stack);
        }
      },
    );
  }
}

/// shadcn-style sidebar: account card at top, nav items in middle, delete at bottom.
class _SettingsSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, String)> sections;
  final ValueChanged<int> onSelected;
  final OpenSenseMapBloc openSenseMapBloc;
  final OpenSenseMapBloc openSenseMapState;

  const _SettingsSidebar({
    required this.selectedIndex,
    required this.sections,
    required this.onSelected,
    required this.openSenseMapBloc,
    required this.openSenseMapState,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAuthenticated = openSenseMapState.isAuthenticated;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidebarAccountCard(
                isAuthenticated: isAuthenticated,
                openSenseMapBloc: openSenseMapBloc,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < sections.length; i++) ...[
                _SidebarItem(
                  icon: sections[i].$1,
                  label: sections[i].$2,
                  selected: i == selectedIndex,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => onSelected(i),
                ),
                const SizedBox(height: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarAccountCard extends StatelessWidget {
  final bool isAuthenticated;
  final OpenSenseMapBloc openSenseMapBloc;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SidebarAccountCard({
    required this.isAuthenticated,
    required this.openSenseMapBloc,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isAuthenticated ? colorScheme.tertiary : loginRequiredColor;
    final onCard = colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: openSenseMapBloc.userData,
            builder: (context, snapshot) {
              final user = snapshot.data?['data']?['me'];
              final email = user?['email'];
              final name = user?['name'];
              return Row(
                spacing: 10,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onCard.withAlpha(40),
                    ),
                    child: Icon(Icons.account_circle, size: 32, color: onCard),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAuthenticated && name != null)
                          Text(name,
                              style: textTheme.bodyLarge?.copyWith(
                                  color: onCard, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)
                        else
                          Text(
                            AppLocalizations.of(context)!.openSenseMapLogin,
                            style: textTheme.bodyLarge?.copyWith(
                                color: onCard, fontWeight: FontWeight.w600),
                          ),
                        if (isAuthenticated && email != null)
                          Text(email,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: onCard.withAlpha(180)),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: onCard.withAlpha(30),
                foregroundColor: onCard,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                textStyle: textTheme.bodySmall,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: openSenseMapBloc.isAuthenticating
                  ? null
                  : () async {
                      if (isAuthenticated) {
                        await openSenseMapBloc.logout();
                      } else {
                        await showAppModalSheet(
                          context: context,
                          useRootNavigator: true,
                          builder: (ctx) => SizedBox(
                            height: MediaQuery.of(ctx).size.height * 0.9,
                            child: const LoginScreen(),
                          ),
                        );
                      }
                    },
              child: openSenseMapBloc.isAuthenticating
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isAuthenticated
                      ? AppLocalizations.of(context)!.generalLogout
                      : AppLocalizations.of(context)!.generalLoginOrRegister),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAccountManagement extends StatefulWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SidebarAccountManagement({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  State<_SidebarAccountManagement> createState() =>
      _SidebarAccountManagementState();
}

class _SidebarAccountManagementState extends State<_SidebarAccountManagement> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isarService = context.read<TrackBloc>().isarService;

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: widget.colorScheme.error,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
      icon: _isDeleting
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: widget.colorScheme.error),
            )
          : const Icon(Icons.delete_outline, size: 18),
      label: Text(localizations.settingsDeleteAllData,
          style: widget.textTheme.bodyMedium
              ?.copyWith(color: widget.colorScheme.error)),
      onPressed: _isDeleting
          ? null
          : () async {
              final confirmed = await showCustomDialog(
                context: context,
                message: localizations.settingsDeleteAllDataConfirmation,
                type: DialogType.confirmation,
              );
              if (confirmed != true || !context.mounted) return;
              setState(() => _isDeleting = true);
              try {
                await isarService.deleteAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(localizations.settingsDeleteAllDataSuccess)));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(localizations.settingsDeleteAllDataError)));
                }
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:
                selected ? colorScheme.secondaryContainer : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fgColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: textTheme.bodyMedium?.copyWith(
                    color: fgColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
