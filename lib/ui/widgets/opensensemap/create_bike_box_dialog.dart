import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/widgets/form/image_select_form_field.dart';

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
          throw 'Please select a model';
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
                title: const Text('Error'),
                content: Text(error.toString()),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
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
      title: const Text('Create senseBox:bike'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ImageSelectFormField(
                controller: _modelController,
                label: 'Model',
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
                    return 'Please select an option';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      value.length < 2 ||
                      value.length > 50) {
                    return 'Name must be between 2 and 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Expanded(child: Text('Your current position will be used')),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submitForm,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Create'),
        ),
      ],
    );
  }
}
