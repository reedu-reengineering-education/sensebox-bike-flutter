import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';

class CreateBikeBoxModal extends StatefulWidget {
  final List<BoxConfiguration>? boxConfigurations;
  final List<Campaign>? campaigns;
  final bool isLoadingBoxConfigurations;
  final bool isLoadingCampaigns;
  final String? boxConfigurationsError;
  final String? campaignsError;
  final BoxConfiguration? Function(String id) getBoxConfigurationById;

  const CreateBikeBoxModal({
    super.key,
    required this.boxConfigurations,
    required this.campaigns,
    required this.isLoadingBoxConfigurations,
    required this.isLoadingCampaigns,
    this.boxConfigurationsError,
    this.campaignsError,
    required this.getBoxConfigurationById,
  });

  @override
  _CreateBikeBoxModalState createState() => _CreateBikeBoxModalState();
}

class _CreateBikeBoxModalState extends State<CreateBikeBoxModal> {
  bool _customTagExpanded = false;
  final _customTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? selectedTag;
  String? selectedBoxConfigId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Set initial box configuration if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && selectedBoxConfigId == null) {
        final configs = widget.boxConfigurations ?? [];
        if (configs.isNotEmpty) {
          setState(() {
            selectedBoxConfigId = configs.first.id;
          });
        }
      }
    });

    // Show error snackbar if campaigns failed to load
    if (widget.campaignsError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.campaignLoadError,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _customTagController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _loading = true;
      });

      try {
        final geolocationBloc = context.read<GeolocationBloc>();
        final opensensemapBloc = context.read<OpenSenseMapBloc>();

        final position = await geolocationBloc.getCurrentLocation();

        if (selectedBoxConfigId == null) {
          throw Exception('Please select a box type');
        }

        final boxConfig = widget.getBoxConfigurationById(selectedBoxConfigId!);
        if (boxConfig == null) {
          throw Exception(
              'Box configuration not found for ID: $selectedBoxConfigId');
        }

        await opensensemapBloc.createSenseBoxBike(
            _nameController.text,
            position.latitude,
            position.longitude,
            boxConfig,
            selectedTag,
            _customTagController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList());

        await opensensemapBloc.fetchSenseBoxes();

        Navigator.of(context).pop();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
          ),
        );
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildBoxConfigurationDropdown(BuildContext context) {
    final configs = widget.boxConfigurations ?? [];
    return DropdownButtonFormField<String>(
      value: selectedBoxConfigId,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.createBoxModel,
      ),
      items: configs
          .map((config) => DropdownMenuItem(
                value: config.id,
                child: Text(config.displayName),
              ))
          .toList(),
      onChanged: _loading
          ? null
          : (value) {
              setState(() {
                selectedBoxConfigId = value;
              });
            },
    );
  }

  Widget _buildCampaignDropdown(BuildContext context) {
    final campaigns = widget.campaigns ?? [];
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.selectCampaign,
      ),
      value: selectedTag,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            AppLocalizations.of(context)!.selectCampaign,
          ),
        ),
        ...campaigns.map((tag) {
          return DropdownMenuItem(
            value: tag.value,
            child: Text(tag.label),
          );
        }).toList(),
      ],
      onChanged: _loading
          ? null
          : (campaigns.isNotEmpty
              ? (value) {
                  setState(() {
                    selectedTag = value;
                  });
                }
              : null),
      disabledHint: Text(
        AppLocalizations.of(context)!.selectCampaign,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        type: MaterialType.transparency,
        color: Colors.transparent,
        child: Center(
          child: Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.createBoxTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    if (widget.isLoadingBoxConfigurations)
                      const CircularProgressIndicator()
                    else
                      _buildBoxConfigurationDropdown(context),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.createBoxName,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 2 ||
                            value.length > 50) {
                          return AppLocalizations.of(context)!
                              .createBoxNameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.isLoadingCampaigns)
                      const CircularProgressIndicator()
                    else
                      _buildCampaignDropdown(context),
                    const SizedBox(height: 4),
                    ExpansionTile(
                      title: Text(
                          AppLocalizations.of(context)!.createBoxAddCustomTag),
                      initiallyExpanded: _customTagExpanded,
                      onExpansionChanged: _loading
                          ? null
                          : (expanded) {
                              setState(() {
                                _customTagExpanded = expanded;
                              });
                            },
                      shape: Border.all(color: Colors.transparent),
                      collapsedShape: Border.all(color: Colors.transparent),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _customTagController,
                                enabled: !_loading,
                                decoration: InputDecoration(
                                  labelText: AppLocalizations.of(context)!
                                      .createBoxCustomTag,
                                ),
                              ),
                              Text(AppLocalizations.of(context)!
                                  .createBoxCustomTagHelper)
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(AppLocalizations.of(context)!
                            .createBoxGeolocationCurrentPosition),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child:
                            Text(AppLocalizations.of(context)!.generalCancel),
                      ),
                      const SizedBox(width: 8),
                      ButtonWithLoader(
                        isLoading: _loading,
                        onPressed: _loading ? null : _submitForm,
                        text: AppLocalizations.of(context)!.generalCreate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
