import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

void showSenseBoxManager(BuildContext context, OpenSenseMapBloc bloc,
    ConfigurationBloc configurationBloc) {
  showAppModalSheet(
    context: context,
    useRootNavigator: true,
    scaleBackground: true,
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
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CustomSpacer(),
                    if (!state.isAuthenticated) ...[
                      _buildLoginCallToAction(context),
                      const SizedBox(height: 8),
                    ],
                    _buildUploadModeTile(context),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SenseBoxSelectionWidget(
                          configurationBloc: widget.configurationBloc),
                    ),
                  ],
                ),
              ),
              // Plus button or reload button at the bottom right corner
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

  Widget _buildLoginCallToAction(BuildContext context) {
    return Material(
      color: loginRequiredColor,
      borderRadius: BorderRadius.circular(borderRadiusSmall),
      child: ListTile(
        leading: const Icon(Icons.login, color: loginRequiredTextColor),
        title: Text(
          AppLocalizations.of(context)!.loginRequiredMessage,
          style: const TextStyle(
            color: loginRequiredTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing:
            const Icon(Icons.arrow_forward, color: loginRequiredTextColor),
        onTap: () => _showLoginModal(context),
      ),
    );
  }

  Future<void> _showLoginModal(BuildContext context) async {
    await showAppModalSheet(
      context: context,
      useRootNavigator: true,
      scaleBackground: false,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: BlocListener<OpenSenseMapBloc, OpenSenseMapState>(
            listenWhen: (previous, current) =>
                !previous.isAuthenticated && current.isAuthenticated,
            listener: (context, state) {
              Navigator.of(context).pop();
            },
            child: const LoginScreen(),
          ),
        );
      },
    );
  }

  Widget _buildUploadModeTile(BuildContext context) {
    final settingsBloc = context.read<SettingsBloc>();

    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final localizations = AppLocalizations.of(context)!;
        final currentMode = settingsState.directUploadMode
            ? localizations.settingsUploadModeDirect
            : localizations.settingsUploadModePostRide;

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: Text(localizations.settingsUploadMode),
            subtitle: Text(
              localizations.settingsUploadModeCurrent(currentMode),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            onTap: () => _showUploadModeDialog(context, settingsBloc),
          ),
        );
      },
    );
  }

  void _showUploadModeDialog(BuildContext context, SettingsBloc settingsBloc) {
    final currentMode = settingsBloc.directUploadMode;
    final localizations = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 375;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.settingsUploadMode),
          titlePadding: isLargeScreen
              ? const EdgeInsets.fromLTRB(24, 24, 24, 24)
              : const EdgeInsets.fromLTRB(12, 12, 12, 12),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: double.maxFinite,
            height:
                isLargeScreen ? null : MediaQuery.of(context).size.height * 0.6,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: isLargeScreen ? 24.0 : 0.0),
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16.0),
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

  Widget _buildActionButton(BuildContext context, OpenSenseMapState state) {
    if (!state.isAuthenticated) {
      return const SizedBox.shrink();
    }

    final configurationBloc = widget.configurationBloc;
    final isLoaded = configurationBloc.boxConfigurations != null &&
        !configurationBloc.isLoadingBoxConfigurations;
    final isLoading = configurationBloc.isLoadingBoxConfigurations;
    final localizations = AppLocalizations.of(context)!;

    if (isLoaded) {
      return FloatingActionButton(
        onPressed: () async {
          await _showCreateSenseBoxDialog(context);
        },
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

  Future<void> _showCreateSenseBoxDialog(BuildContext context) async {
    final configurationBloc = widget.configurationBloc;
    return showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
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
