import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/widgets/form/image_select_form_field.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CreateBikeBoxDialog extends StatefulWidget {
  const CreateBikeBoxDialog({super.key});

  @override
  _CreateBikeBoxDialogState createState() => _CreateBikeBoxDialogState();
}

class _CreateBikeBoxDialogState extends State<CreateBikeBoxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = ImageSelectController<SenseBoxBikeModel>();

  bool _loading = false;

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
        );

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
    // final localization = AppLocalizations.of(context);

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
              const SizedBox(height: 20),
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
