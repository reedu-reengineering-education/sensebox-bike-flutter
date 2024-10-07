import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';

class SenseBoxSelectionWidget extends StatefulWidget {
  const SenseBoxSelectionWidget({super.key});

  @override
  _SenseBoxSelectionWidgetState createState() =>
      _SenseBoxSelectionWidgetState();
}

class _SenseBoxSelectionWidgetState extends State<SenseBoxSelectionWidget> {
  late OpenSenseMapBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    bloc.fetchAndSelectSenseBox(); // Fetch senseBoxes on widget init
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenSenseMapBloc>(
      builder: (context, bloc, child) {
        if (bloc.senseBoxes.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_bike, size: 48),
              const SizedBox(height: 16),
              Text('No senseBoxes found',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Create one using the "+" button'),
            ],
          ));
        }

        return ListView.builder(
            itemCount: bloc.senseBoxes.length,
            itemBuilder: (context, index) {
              final senseBox = SenseBox.fromJson(bloc.senseBoxes[index]);
              final isSelected = senseBox.id == bloc.selectedSenseBox?.id;

              return ListTile(
                title: Text(senseBox.name ?? 'Unnamed senseBox'),
                subtitle:
                    senseBox.grouptag != null && senseBox.grouptag!.isNotEmpty
                        ? Wrap(
                            spacing: 8,
                            children: senseBox.grouptag!
                                .map((tag) => Badge(
                                    label: Text(tag),
                                    backgroundColor: Colors.primaries.first))
                                .toList(),
                          )
                        : null,
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  bloc.setSelectedSenseBox(senseBox);
                  Navigator.pop(context); // Go back after selecting
                },
              );
            });
      },
    );
  }
}
