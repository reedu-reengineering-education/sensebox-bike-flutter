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
  late Future<List> _senseBoxFuture;

  late OpenSenseMapBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    _senseBoxFuture = bloc.fetchAndSelectSenseBox(); // Call once
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List>(
      future: _senseBoxFuture, // Use the future defined in initState
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No senseBoxes available'));
        }

        final senseBoxes = snapshot.data!;
        return ListView.builder(
          itemCount: senseBoxes.length,
          itemBuilder: (context, index) {
            final senseBox = SenseBox.fromJson(senseBoxes[index]);
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
              onTap: () {
                bloc.setSelectedSenseBox(senseBox);
                Navigator.pop(context); // Go back after selecting
              },
            );
          },
        );
      },
    );
  }
}
