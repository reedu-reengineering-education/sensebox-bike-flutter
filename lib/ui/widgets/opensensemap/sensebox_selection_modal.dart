import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

void showSenseBoxManager(BuildContext context, OpenSenseMapBloc bloc,
    ConfigurationBloc configurationBloc) {
  showAppModalSheet(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext context) {
      return _SenseBoxManagementModal(
        bloc: bloc,
        configurationBloc: configurationBloc,
      );
    },
  );
}

@Deprecated('Use showSenseBoxManager instead.')
void showSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc,
    ConfigurationBloc configurationBloc) {
  showSenseBoxManager(context, bloc, configurationBloc);
}

class _SenseBoxManagementModal extends StatefulWidget {
  final OpenSenseMapBloc bloc;
  final ConfigurationBloc configurationBloc;

  const _SenseBoxManagementModal({
    required this.bloc,
    required this.configurationBloc,
  });

  @override
  State<_SenseBoxManagementModal> createState() =>
      _SenseBoxManagementModalState();
}

class _SenseBoxManagementModalState extends State<_SenseBoxManagementModal> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpenSenseMapBloc, OpenSenseMapState>(
      builder: (context, state) {
        final openSenseMapBloc = context.read<OpenSenseMapBloc>();
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  spacing: 12,
                  children: [
                    _buildSettingsGrid(context),
                    state.isAuthenticated
                        ? Expanded(
                            child: buildLoginLogoutSection(
                              context,
                              openSenseMapBloc,
                              state,
                            ),
                          )
                        : buildLoginLogoutSection(
                            context,
                            openSenseMapBloc,
                            state,
                          ),
                  ],
                ),
              ),
              Positioned(
                bottom: 32,
                right: 32,
                child: _buildActionButton(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildLoginLogoutSection(BuildContext context,
      OpenSenseMapBloc openSenseMapBloc, OpenSenseMapState openSenseMapState) {
    final isAuthenticated = openSenseMapState.isAuthenticated;

    return buildSettingsContainer(
      context,
      isAuthenticated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: openSenseMapBloc.userData,
            builder: (context, snapshot) {
              return buildUserInfoRow(
                  context, isAuthenticated, snapshot.data, openSenseMapBloc);
            },
          ),
          const SizedBox(height: 16),
          buildLoginLogoutButton(context, isAuthenticated, openSenseMapBloc),
          const SizedBox(height: 8),
          if (isAuthenticated)
            Expanded(
              child: SenseBoxSelectionWidget(
                configurationBloc: widget.configurationBloc,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildSettingsContainer(BuildContext context, bool isAuthenticated,
      {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isAuthenticated
            ? Theme.of(context).colorScheme.tertiary
            : loginRequiredColor,
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget buildUserInfoRow(BuildContext context, bool isAuthenticated,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        buildUserIcon(context),
        const SizedBox(width: 12),
        if (isAuthenticated)
          buildAuthenticatedUserInfo(context, userData, openSenseMapBloc)
        else
          buildUnauthenticatedUserInfo(context),
      ],
    );
  }

  Widget buildUserIcon(BuildContext context) {
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

  Widget buildAuthenticatedUserInfo(BuildContext context,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
    if (openSenseMapBloc.isAuthenticating) {
      return const CircularProgressIndicator();
    }
    if (userData == null) {
      return const CircularProgressIndicator();
    }
    return buildUserDataDisplay(context, userData, openSenseMapBloc);
  }

  Widget buildUserDataDisplay(BuildContext context,
      Map<String, dynamic>? userData, OpenSenseMapBloc openSenseMapBloc) {
    final user = userData?['data']?['me'];
    final email = user?['email'] ?? "No email";
    final name = user?['name'] ?? "John Doe";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          email,
          style: getPrimaryTextStyle(context),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          name,
          style: getSecondaryTextStyle(context),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget buildUnauthenticatedUserInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.openSenseMapLogin,
          style: getPrimaryTextStyle(context),
        ),
        Text(
          AppLocalizations.of(context)!.openSenseMapLoginDescription,
          style: getSecondaryTextStyle(context),
          softWrap: true,
        ),
      ],
    );
  }

  Widget buildLoginLogoutButton(BuildContext context, bool isAuthenticated,
      OpenSenseMapBloc openSenseMapBloc) {
    return ButtonWithLoader(
      inverted: Theme.of(context).brightness == Brightness.light,
      isLoading: openSenseMapBloc.isAuthenticating,
      onPressed: openSenseMapBloc.isAuthenticating
          ? null
          : () => handleLoginLogoutAction(
              context, isAuthenticated, openSenseMapBloc),
      text: isAuthenticated
          ? AppLocalizations.of(context)!.generalLogout
          : AppLocalizations.of(context)!.generalLoginOrRegister,
      width: 1,
    );
  }

  Future<void> handleLoginLogoutAction(BuildContext context,
      bool isAuthenticated, OpenSenseMapBloc openSenseMapBloc) async {
    if (isAuthenticated) {
      await openSenseMapBloc.logout();
    } else {
      showAppModalSheet(
        context: context,
        useRootNavigator: true,
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: const LoginScreen(),
        ),
      );
    }
  }

  TextStyle getPrimaryTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );
  }

  TextStyle getSecondaryTextStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onTertiaryContainer,
    );
  }

  Widget _buildSettingsGrid(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Expanded(child: _buildUploadModeTile(context)),
        Expanded(child: _buildPrivacyZonesTile(context)),
      ],
    );
  }

  Widget _buildUploadModeTile(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final localizations = AppLocalizations.of(context)!;
        final currentMode = settingsState.directUploadMode
            ? localizations.settingsUploadModeDirect
            : localizations.settingsUploadModePostRide;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showUploadModeDialog(context, settingsBloc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(borderRadiusSmall),
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  localizations.settingsUploadMode,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  localizations.settingsUploadModeCurrent(currentMode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyZonesTile(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final localizations = AppLocalizations.of(context)!;
        final zonesCount = settingsState.privacyZones.length;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.push(AppRoutes.exclusionZones);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(borderRadiusSmall),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Badge.count(
                      count: zonesCount,
                      backgroundColor: colorScheme.primaryFixedDim,
                      textColor: colorScheme.onPrimary,
                    ),
                  ],
                ),
                Text(
                  localizations.generalPrivacyZones,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  localizations.privacyZoneDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUploadModeDialog(BuildContext context, SettingsBloc settingsBloc) {
    final currentMode = settingsBloc.directUploadMode;
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 375;

    showAppDialog(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return AppAlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          title: Text(
            localizations.settingsUploadMode,
            style: theme.textTheme.headlineSmall,
          ),
          titlePadding: isLargeScreen
              ? const EdgeInsets.fromLTRB(24, 26, 24, 18)
              : const EdgeInsets.fromLTRB(20, 22, 20, 16),
          contentPadding: EdgeInsets.zero,
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          content: SizedBox(
            width: screenSize.width * 0.92,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
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
                              localizations
                                  .settingsUploadModePostRideDescription,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16.0),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                    ],
                  ),
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

  Widget _buildActionButton(BuildContext context, OpenSenseMapState state) {
    if (!state.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final configurationBloc = widget.configurationBloc;
    final isLoaded = configurationBloc.boxConfigurations != null &&
        !configurationBloc.isLoadingBoxConfigurations;
    final isLoading = configurationBloc.isLoadingBoxConfigurations;
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoaded) {
      return FloatingActionButton(
        onPressed: () async {
          await _showCreateSenseBoxDialog(context);
        },
        backgroundColor: colorScheme.onTertiaryContainer,
        foregroundColor: colorScheme.tertiaryContainer,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      );
    } else {
      return ButtonWithLoader(
        isLoading: isLoading,
        onPressed: isLoading
            ? null
            : () async {
                await configurationBloc.loadBoxConfigurations();
                if (mounted) {
                  setState(() {});
                  final bloc = widget.bloc;
                  if (bloc.senseBoxes.isEmpty) {
                    await bloc.fetchSenseBoxes();
                  }
                }
              },
        text: localizations.reloadConfiguration,
      );
    }
  }

  Future<Object> _showCreateSenseBoxDialog(BuildContext context) async {
    final configurationBloc = widget.configurationBloc;
    return showAppModalSheet(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return CreateBikeBoxModal(
          boxConfigurations: configurationBloc.boxConfigurations,
          campaigns: configurationBloc.campaigns,
          isLoadingBoxConfigurations:
              configurationBloc.isLoadingBoxConfigurations,
          isLoadingCampaigns: configurationBloc.isLoadingCampaigns,
          boxConfigurationsError: configurationBloc.boxConfigurationsError,
          campaignsError: configurationBloc.campaignsError,
          getBoxConfigurationById: (id) =>
              configurationBloc.getBoxConfigurationById(id),
        );
      },
    );
  }
}
