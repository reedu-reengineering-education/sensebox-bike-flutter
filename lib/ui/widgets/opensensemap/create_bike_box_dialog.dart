import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

class CreateBikeBoxDialog extends StatefulWidget {
  @override
  _CreateBikeBoxDialogState createState() => _CreateBikeBoxDialogState();
}

class _CreateBikeBoxDialogState extends State<CreateBikeBoxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedModel = 'atrai';
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

        await opensensemapBloc.createSenseBoxBike(
          _nameController.text,
          position.latitude,
          position.longitude,
          _selectedModel == "default"
              ? SenseBoxBikeModel.defaultModel
              : SenseBoxBikeModel.atrai,
        );

        // final newBox = await createSenseBoxBike(
        //   _nameController.text,
        //   position.latitude,
        //   position.longitude,
        //   _selectedModel,
        // );

        // await context.read<AuthStore>().refreshBoxes();
        // context.read<AuthStore>().setSelectedBox(newBox);
        Navigator.of(context).pop();
      } catch (error) {
        // showToast(context, 'Failed to create SenseBox Bike');
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
      title: Text('Create Bike Box'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: InputDecoration(labelText: 'Model'),
                items: [
                  DropdownMenuItem(value: 'default', child: Text('Default')),
                  DropdownMenuItem(value: 'atrai', child: Text('Atrai')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value!;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a model' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'senseBox:bike',
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
              SizedBox(height: 20),
              Row(
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
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submitForm,
          child: _loading ? CircularProgressIndicator() : Text('Create'),
        ),
      ],
    );
  }
}
