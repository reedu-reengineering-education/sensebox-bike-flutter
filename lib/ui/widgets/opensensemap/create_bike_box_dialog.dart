import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/widgets/form/image_select_form_field.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/tag_service.dart';

class CreateBikeBoxDialog extends StatefulWidget {
  final TagService tagService;

  const CreateBikeBoxDialog({super.key, required this.tagService});

  @override
  _CreateBikeBoxDialogState createState() => _CreateBikeBoxDialogState();
}

class _CreateBikeBoxDialogState extends State<CreateBikeBoxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = ImageSelectController<SenseBoxBikeModel>();
  List<Map<String, String>> availableTags = [];
  String? selectedTag;
  bool _loading = false;

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
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.generalError),
            content: Text(AppLocalizations.of(context)!.campaignLoadError),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context)!.generalOk),
              ),
            ],
          );
        },
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

        if (_modelController.value == null) {
          throw AppLocalizations.of(context)!.createBoxModelErrorEmpty;
        }

        await opensensemapBloc.createSenseBoxBike(
            _nameController.text,
            position.latitude,
            position.longitude,
            _modelController.value ?? SenseBoxBikeModel.classic,
            selectedTag);

        await opensensemapBloc.fetchSenseBoxes();

        Navigator.of(context).pop();
      } catch (error) {
        // alert
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(AppLocalizations.of(context)!.generalError),
                content: Text(error.toString()),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(AppLocalizations.of(context)!.generalOk),
                  ),
                ],
              );
            });
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.createBoxTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ImageSelectFormField(
                controller: _modelController,
                label: AppLocalizations.of(context)!.createBoxModel,
                items: [
                  ImageSelectItem(
                    value: SenseBoxBikeModel.classic,
                    label: 'Classic',
                    imagePath: 'assets/images/sensebox_bike_classic.webp',
                  ),
                  ImageSelectItem(
                    value: SenseBoxBikeModel.atrai,
                    label: 'ATRAI',
                    imagePath: 'assets/images/sensebox_bike_atrai.webp',
                  ),
                ],
                validator: (value) {
                  if (value == null) {
                    return AppLocalizations.of(context)!
                        .createBoxModelErrorEmpty;
                  }
                  return null;
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
                    labelText: AppLocalizations.of(context)!.selectCampaign),
                items: availableTags.map((tag) {
                  return DropdownMenuItem(
                      value: tag['value'], child: Text(tag['label'] ?? ''));
                }).toList(),
                onChanged: availableTags.isNotEmpty
                    ? (value) {
                        setState(() {
                          selectedTag = value;
                        });
                      }
                    : null, // Disable interaction if no tags are available
                disabledHint:
                    Text(AppLocalizations.of(context)!.noCampaignsAvailable),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(AppLocalizations.of(context)!
                          .createBoxGeolocationCurrentPosition)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(AppLocalizations.of(context)!.generalCancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submitForm,
          child: _loading
              ? const CircularProgressIndicator()
              : Text(AppLocalizations.of(context)!.generalCreate),
        ),
      ],
    );
  }
}
