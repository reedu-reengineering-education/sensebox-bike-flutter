import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/tag_service.dart';
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
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: () async =>
                    {_showCreateSenseBoxDialog(context, bloc)},
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(child: SenseBoxSelectionWidget())
        ],
      ),
    ),
  );
}

Future<void> _showCreateSenseBoxDialog(
    BuildContext context, OpenSenseMapBloc bloc) {
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return CreateBikeBoxDialog(tagService: TagService());
      });
}
