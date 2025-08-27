import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/tag_service.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';

class CreateBikeBoxModal extends StatefulWidget {
  final TagService tagService;

  const CreateBikeBoxModal({super.key, required this.tagService});

  @override
  _CreateBikeBoxModalState createState() => _CreateBikeBoxModalState();
}

class _CreateBikeBoxModalState extends State<CreateBikeBoxModal> {
  bool _customTagExpanded = false;
  final _customTagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<Map<String, String>> availableTags = [];
  String? selectedTag;
  bool _loading = false;
  SenseBoxBikeModel _selectedModel = SenseBoxBikeModel.atrai;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await widget.tagService.loadTags();

      setState(() {
        availableTags = tags;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.campaignLoadError),
        ),
      );
    }
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

        await opensensemapBloc.createSenseBoxBike(
            _nameController.text,
            position.latitude,
            position.longitude,
            _selectedModel,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            constraints: BoxConstraints(
              maxWidth: 500,
            ),
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
                  DropdownButtonFormField<SenseBoxBikeModel>(
                    value: _selectedModel,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.createBoxModel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: SenseBoxBikeModel.atrai,
                        child: Text('2025'),
                      ),
                      DropdownMenuItem(
                        value: SenseBoxBikeModel.classic,
                        child: Text('2022'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedModel = value ?? SenseBoxBikeModel.atrai;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.createBoxName,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          value.length < 2 ||
                          value.length > 50) {
                        return AppLocalizations.of(context)!.createBoxNameError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.selectCampaign,
                    ),
                    value: selectedTag,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child:
                            Text(AppLocalizations.of(context)!.selectCampaign),
                      ),
                      ...availableTags.map((tag) {
                        return DropdownMenuItem(
                            value: tag['value'],
                            child: Text(tag['label'] ?? ''));
                      }).toList(),
                    ],
                    onChanged: availableTags.isNotEmpty
                        ? (value) {
                            setState(() {
                              selectedTag = value;
                            });
                          }
                        : null,
                    disabledHint:
                        Text(AppLocalizations.of(context)!.selectCampaign),
                  ),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    title: Text(
                        AppLocalizations.of(context)!.createBoxAddCustomTag),
                    initiallyExpanded: _customTagExpanded,
                    onExpansionChanged: (expanded) {
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
                        onPressed: () {
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
        ));
  }
}
