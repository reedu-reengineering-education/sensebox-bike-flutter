import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_dialog.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

void showSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc) {
  showModalBottomSheet(
    context: context,
    clipBehavior: Clip.antiAlias,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return _buildSenseBoxSelection(context, bloc);
    },
  );
}

Widget _buildSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc) {
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
              const Expanded(child: SenseBoxSelectionWidget()),
            ],
          ),
        ),
        // Plus button at the bottom right corner
        Positioned(
          bottom: 32,
          right: 32,
          child: FloatingActionButton(
            onPressed: () async {
              await _showCreateSenseBoxDialog(context, bloc);
            },
            shape: const CircleBorder(), 
            child: const Icon(Icons.add),
          ),
        ),
      ],
    ),
  );
}

Future<void> _showCreateSenseBoxDialog(
    BuildContext context, OpenSenseMapBloc bloc) {
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return const CreateBikeBoxDialog();
      });
}
