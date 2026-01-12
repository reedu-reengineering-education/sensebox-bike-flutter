import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

void showSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc,
    ConfigurationBloc configurationBloc) {
  showModalBottomSheet(
    context: context,
    clipBehavior: Clip.antiAlias,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return _SenseBoxSelectionModal(
        bloc: bloc,
        configurationBloc: configurationBloc,
      );
    },
  );
}

class _SenseBoxSelectionModal extends StatefulWidget {
  final OpenSenseMapBloc bloc;
  final ConfigurationBloc configurationBloc;

  const _SenseBoxSelectionModal({
    required this.bloc,
    required this.configurationBloc,
  });

  @override
  State<_SenseBoxSelectionModal> createState() =>
      _SenseBoxSelectionModalState();
}

class _SenseBoxSelectionModalState extends State<_SenseBoxSelectionModal> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Close button at the top right corner
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context); // Close the modal
                    },
                  ),
                ),
                const CustomSpacer(),
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
            child: _buildActionButton(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
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
                  setState(() {}); // Rebuild to update button state
                  // Reload senseBoxes if list is empty, otherwise they'll use new config automatically
                  final bloc = widget.bloc;
                  if (bloc.senseBoxes.isEmpty) {
                    await bloc.fetchSenseBoxes(page: 0);
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
