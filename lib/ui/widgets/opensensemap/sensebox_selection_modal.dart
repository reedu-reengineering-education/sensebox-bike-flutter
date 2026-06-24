import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
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
    return Consumer<OpenSenseMapBloc>(
      builder: (context, bloc, child) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
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
              Positioned(
                bottom: 32,
                right: 32,
                child: ListenableBuilder(
                  listenable: widget.configurationBloc,
                  builder: (context, _) => _buildCreateButton(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final configurationBloc = widget.configurationBloc;
    final isLoading = configurationBloc.isLoadingBoxConfigurations;

    return FloatingActionButton(
      onPressed: isLoading
          ? null
          : () async {
              if (configurationBloc.boxConfigurations == null) {
                await configurationBloc.loadAll();
              }
              if (!context.mounted) return;
              await _showCreateSenseBoxDialog(context);
            },
      shape: const CircleBorder(),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
    );
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
