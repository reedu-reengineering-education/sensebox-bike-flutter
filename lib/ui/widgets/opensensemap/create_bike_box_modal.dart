import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/common/labeled_text_form_field.dart';
import 'package:sensebox_bike/ui/widgets/common/dropdown_form_field.dart';
import 'package:sensebox_bike/ui/utils/common.dart';

/// Bottom sheet for registering a new senseBox on openSenseMap.
///
/// Reading order follows the task: name the box, pick what hardware it is
/// (a predefined model or a custom sensor selection), then the optional
/// campaign and group tags. Actions stay pinned below the scrolling form.
class CreateBikeBoxModal extends StatefulWidget {
  final List<BoxConfiguration>? boxConfigurations;
  final List<Campaign>? campaigns;
  final bool isLoadingBoxConfigurations;
  final bool isLoadingCampaigns;
  final String? boxConfigurationsError;
  final String? campaignsError;
  final BoxConfiguration? Function(String id) getBoxConfigurationById;

  /// Sensors a custom box can be assembled from. When null or empty the
  /// "Custom" model option is hidden.
  final List<SensorCatalogEntry>? sensorCatalog;

  const CreateBikeBoxModal({
    super.key,
    required this.boxConfigurations,
    required this.campaigns,
    required this.isLoadingBoxConfigurations,
    required this.isLoadingCampaigns,
    this.boxConfigurationsError,
    this.campaignsError,
    required this.getBoxConfigurationById,
    this.sensorCatalog,
  });

  @override
  State<CreateBikeBoxModal> createState() => _CreateBikeBoxModalState();
}

class _CreateBikeBoxModalState extends State<CreateBikeBoxModal> {
  // Spacing roles: tight inside a group, generous between groups.
  static const double _gutter = 20;
  static const double _groupGap = 24;
  static const double _labelGap = 10;

  final _customTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _boxConfigKey = GlobalKey<FormFieldState<String>>();
  final _campaignKey = GlobalKey<FormFieldState<String>>();
  final _nameKey = GlobalKey<FormFieldState<String>>();
  bool _loading = false;
  bool _showAllModels = false;
  String? _selectedBoxConfigId;
  final Set<String> _customSensorKeys = {};

  List<SensorCatalogEntry> get _catalog => widget.sensorCatalog ?? const [];
  List<BoxConfiguration> get _configs => widget.boxConfigurations ?? const [];

  /// Featured models, or every model when the configuration marks none
  /// (e.g. an older remote file), so nothing becomes unreachable.
  List<BoxConfiguration> get _featuredConfigs {
    final featured = _configs.where((config) => config.featured).toList();
    return featured.isEmpty ? _configs : featured;
  }

  bool get _isCustomSelected =>
      _selectedBoxConfigId == BoxConfiguration.customId;

  @override
  void initState() {
    super.initState();
    _selectedBoxConfigId = _configs.isNotEmpty
        ? _featuredConfigs.first.id
        : (_catalog.isNotEmpty ? BoxConfiguration.customId : null);

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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
    });

    try {
      final geolocationBloc = context.read<GeolocationBloc>();
      final opensensemapBloc = context.read<OpenSenseMapBloc>();
      final customModelName =
          AppLocalizations.of(context)!.createBoxModelCustom;

      final position = await geolocationBloc.getCurrentLocation();

      final selectedBoxConfigId = _boxConfigKey.currentState?.value;
      if (selectedBoxConfigId == null) {
        throw Exception('Please select a box type');
      }

      final boxConfig = selectedBoxConfigId == BoxConfiguration.customId
          ? BoxConfiguration.custom(
              catalog: _catalog,
              sensorKeys: _customSensorKeys,
              displayName: customModelName,
            )
          : widget.getBoxConfigurationById(selectedBoxConfigId);
      if (boxConfig == null) {
        throw Exception(
            'Box configuration not found for ID: $selectedBoxConfigId');
      }

      final boxName = _nameKey.currentState?.value ?? '';
      final selectedTag = _campaignKey.currentState?.value;
      final customTags = parseCustomTags(_customTagController.text);

      await opensensemapBloc.createSenseBoxBike(boxName, position.longitude,
          position.latitude, boxConfig, selectedTag, customTags);

      await opensensemapBloc.fetchSenseBoxes(page: 0);

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.createBoxTitle,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.my_location_outlined, size: 16, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                localizations.createBoxGeolocationCurrentPosition,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  /// Models are shown as small cards in a two-column grid. Featured models
  /// and "Custom" are always visible; the rest wait behind "More models" so
  /// the common choice is not buried among legacy hardware revisions.
  Widget _buildModelSelector(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FormField<String>(
      key: _boxConfigKey,
      initialValue: _selectedBoxConfigId,
      validator: (value) =>
          value == null ? localizations.createBoxModelErrorEmpty : null,
      builder: (state) {
        void select(String id) {
          state.didChange(id);
          setState(() => _selectedBoxConfigId = id);
        }

        final featured = _featuredConfigs;
        final others = _configs.where((c) => !featured.contains(c)).toList();
        final selectedConfig =
            _configs.where((config) => config.id == state.value).firstOrNull;
        // Never hide the current selection behind the collapsed section.
        final showOthers = _showAllModels ||
            (selectedConfig != null && others.contains(selectedConfig));

        List<_ModelOption> options(Iterable<BoxConfiguration> configs) =>
            configs
                .map((config) => _ModelOption(
                      id: config.id,
                      title: config.displayName,
                      subtitle: localizations.createBoxSensorCount(
                          config.sensors.map((s) => s.key).toSet().length),
                      icon: config.featured
                          ? Icons.pedal_bike
                          : Icons.developer_board_outlined,
                    ))
                .toList();

        final primaryOptions = [
          ...options(featured),
          if (_catalog.isNotEmpty)
            _ModelOption(
              id: BoxConfiguration.customId,
              title: localizations.createBoxModelCustom,
              subtitle: localizations.createBoxModelCustomDescription,
              icon: Icons.tune,
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModelGrid(context, primaryOptions, state.value, select),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _loading
                    ? null
                    : () => setState(() => _showAllModels = !showOthers),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: AnimatedRotation(
                  turns: showOthers ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: const Icon(Icons.expand_more, size: 20),
                ),
                label: Text(localizations.createBoxMoreModels),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: showOthers
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildModelGrid(
                            context, options(others), state.value, select),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
            if (state.hasError) _buildErrorText(context, state.errorText!),
            if (_isCustomSelected) ...[
              const SizedBox(height: 20),
              _buildCustomSensorPicker(context),
            ] else if (selectedConfig != null &&
                selectedConfig.sensors.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildSensorSummary(context, selectedConfig),
            ],
          ],
        );
      },
    );
  }

  Widget _buildModelGrid(
    BuildContext context,
    List<_ModelOption> options,
    String? selectedId,
    ValueChanged<String> onSelect,
  ) {
    const gap = 10.0;
    // Pairs in IntrinsicHeight rows: both cards in a row share the height of
    // the taller one, so a two-line model name never leaves a ragged grid.
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      Widget cell(int index) => Expanded(
            child: index < options.length
                ? _buildModelCard(
                    context,
                    options[index],
                    selected: options[index].id == selectedId,
                    onTap: _loading ? null : () => onSelect(options[index].id),
                  )
                : const SizedBox.shrink(),
          );
      if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [cell(i), const SizedBox(width: gap), cell(i + 1)],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildModelCard(
    BuildContext context,
    _ModelOption option, {
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected ? colorScheme.onPrimary : colorScheme.onSurface;
    final muted = selected
        ? colorScheme.onPrimary.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colorScheme.primary : colorScheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(option.icon, size: 22, color: foreground),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child:
                          Icon(Icons.check_circle, size: 18, color: foreground),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  option.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One quiet line telling what the chosen model measures, so cryptic
  /// model names like "2022" still lead to an informed choice.
  Widget _buildSensorSummary(BuildContext context, BoxConfiguration config) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final labels = config.sensors
        .map((sensor) => sensor.key)
        .toSet()
        .map((key) => _sensorKeyLabel(localizations, key))
        .join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.sensors, size: 16, color: muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            labels,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSensorPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context)!;
    final keys = BoxConfiguration.selectableSensorKeys(_catalog);

    return FormField<Set<String>>(
      validator: (_) => _customSensorKeys.isEmpty
          ? localizations.createBoxCustomSensorsErrorEmpty
          : null,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.createBoxCustomSensors,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // No clipping: chips scroll into the side gutters and are cut
            // by the sheet edge, which signals there is more to swipe to.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                spacing: 8,
                children: keys.map((key) {
                  final selected = _customSensorKeys.contains(key);
                  return FilterChip(
                    label: Text(_sensorKeyLabel(localizations, key)),
                    selected: selected,
                    onSelected: _loading
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _customSensorKeys.add(key);
                              } else {
                                _customSensorKeys.remove(key);
                              }
                            });
                            state.didChange(_customSensorKeys);
                          },
                    selectedColor:
                        colorScheme.onSurface.withValues(alpha: 0.10),
                    backgroundColor: colorScheme.surface,
                    checkmarkColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: selected
                          ? colorScheme.onSurface.withValues(alpha: 0.4)
                          : colorScheme.outline,
                    ),
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (state.hasError) _buildErrorText(context, state.errorText!),
          ],
        );
      },
    );
  }

  Widget _buildErrorText(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  String _sensorKeyLabel(AppLocalizations localizations, String key) {
    switch (key) {
      case 'temperature':
        return localizations.sensorTemperature;
      case 'humidity':
        return localizations.sensorHumidity;
      case 'finedust':
        return localizations.sensorFinedust;
      case 'distance':
        return localizations.sensorDistance;
      case 'distance_right':
        return localizations.sensorDistanceRight;
      case 'overtaking':
        return localizations.sensorOvertaking;
      case 'surface_classification':
        return localizations.sensorSurface;
      case 'surface_anomaly':
        return localizations.sensorSurfaceAnomaly;
      case 'acceleration':
        return localizations.sensorAcceleration;
      case 'gps':
        return localizations.sensorSpeed;
      default:
        // Keys added to the remote catalog later fall back to its label.
        return _catalog.where((entry) => entry.key == key).firstOrNull?.label ??
            key;
    }
  }

  Widget _buildCampaignDropdown(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final campaigns = widget.campaigns ?? [];
    final items = [
      DropdownItem<String>(
        value: null,
        label: localizations.createBoxCampaignNone,
      ),
      ...campaigns.map((campaign) => DropdownItem<String>(
            value: campaign.value,
            label: campaign.label,
          )),
    ];

    return DropdownFormField<String>(
      key: _campaignKey,
      labelText: localizations.createBoxCampaign,
      items: items,
      enabled: !_loading && campaigns.isNotEmpty,
      disabledHint: localizations.createBoxCampaignNone,
    );
  }

  Widget _buildActions(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 16),
      child: Row(
        children: [
          // Natural width so longer translations ("Abbrechen") never wrap;
          // the primary action takes the remaining space.
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outline),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(localizations.generalCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ButtonWithLoader(
                isLoading: _loading,
                onPressed: _loading ? null : _submitForm,
                text: localizations.generalCreate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final maxHeight =
        (mediaQuery.size.height * 0.88 - keyboardInset - mediaQuery.padding.top)
            .clamp(240.0, double.infinity);

    return SafeArea(
      top: false,
      child: Padding(
        // Lift the sheet above the keyboard so the focused field and the
        // actions stay visible while typing.
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: _groupGap),
                        LabeledTextFormField(
                          key: _nameKey,
                          labelText: localizations.createBoxName,
                          enabled: !_loading,
                          validator: (value) =>
                              boxNameValidator(context, value),
                        ),
                        const SizedBox(height: _groupGap),
                        _buildSectionLabel(
                            context, localizations.createBoxModel),
                        const SizedBox(height: _labelGap),
                        if (widget.isLoadingBoxConfigurations)
                          const Center(child: CircularProgressIndicator())
                        else
                          _buildModelSelector(context),
                        const SizedBox(height: _groupGap + 4),
                        if (widget.isLoadingCampaigns)
                          const Center(child: CircularProgressIndicator())
                        else
                          _buildCampaignDropdown(context),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customTagController,
                          enabled: !_loading,
                          decoration: InputDecoration(
                            labelText: localizations.createBoxCustomTag,
                            helperText: localizations.createBoxCustomTagHelper,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModelOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
