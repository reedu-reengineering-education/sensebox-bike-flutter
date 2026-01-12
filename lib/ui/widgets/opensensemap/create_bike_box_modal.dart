import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/labeled_text_form_field.dart';
import 'package:sensebox_bike/ui/widgets/common/dropdown_form_field.dart';
import 'package:sensebox_bike/ui/utils/common.dart';

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
  final _boxConfigKey = GlobalKey<FormFieldState<String>>();
  final _campaignKey = GlobalKey<FormFieldState<String>>();
  final _nameKey = GlobalKey<FormFieldState<String>>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final configs = widget.boxConfigurations ?? [];
        if (configs.isNotEmpty && _boxConfigKey.currentState?.value == null) {
          _boxConfigKey.currentState?.didChange(configs.first.id);
        }
      }
    });

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

        final selectedBoxConfigId = _boxConfigKey.currentState?.value;
        if (selectedBoxConfigId == null) {
          throw Exception('Please select a box type');
        }

        final boxConfig = widget.getBoxConfigurationById(selectedBoxConfigId);
        if (boxConfig == null) {
          throw Exception(
              'Box configuration not found for ID: $selectedBoxConfigId');
        }

        final boxName = _nameKey.currentState?.value ?? '';
        final selectedTag = _campaignKey.currentState?.value;
        final customTags = parseCustomTags(_customTagController.text);

        await opensensemapBloc.createSenseBoxBike(
            boxName,
            position.latitude,
            position.longitude,
            boxConfig,
            selectedTag,
            customTags);

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
    return DropdownFormField<String>(
      key: _boxConfigKey,
      labelText: AppLocalizations.of(context)!.createBoxModel,
      items: configs
          .map((config) => DropdownItem<String>(
                value: config.id,
                label: config.displayName,
              ))
          .toList(),
      enabled: !_loading,
      validator: (value) {
        if (value == null) {
          return AppLocalizations.of(context)!.createBoxModel;
        }
        return null;
      },
    );
  }

  Widget _buildCampaignDropdown(BuildContext context) {
    final campaigns = widget.campaigns ?? [];
    final items = [
      DropdownItem<String>(
        value: null,
        label: AppLocalizations.of(context)!.selectCampaign,
      ),
      ...campaigns.map((campaign) => DropdownItem<String>(
            value: campaign.value,
            label: campaign.label,
          )),
    ];

    return DropdownFormField<String>(
      key: _campaignKey,
      labelText: AppLocalizations.of(context)!.selectCampaign,
      items: items,
      enabled: !_loading && campaigns.isNotEmpty,
      disabledHint: AppLocalizations.of(context)!.selectCampaign,
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
                    LabeledTextFormField(
                      key: _nameKey,
                      labelText: AppLocalizations.of(context)!.createBoxName,
                      enabled: !_loading,
                      validator: (value) => boxNameValidator(context, value),
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
