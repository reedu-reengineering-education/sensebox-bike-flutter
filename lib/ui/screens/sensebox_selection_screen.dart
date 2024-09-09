import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';

class SenseBoxSelectionScreen extends StatefulWidget {
  @override
  _SenseBoxSelectionScreenState createState() =>
      _SenseBoxSelectionScreenState();
}

class _SenseBoxSelectionScreenState extends State<SenseBoxSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      // Fetch senseBoxes when the widget is built
      Provider.of<OpenSenseMapBloc>(context, listen: false)
          .fetchAndSelectSenseBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select a SenseBox'),
      ),
      body: Consumer<OpenSenseMapBloc>(
        builder: (context, bloc, child) {
          if (bloc.senseBoxes.isEmpty) {
            // if (bloc.isFetching) {
            //   return Center(child: CircularProgressIndicator());
            // } else {
            return Center(child: Text('No senseBoxes available'));
            // }
          }

          return ListView.builder(
            itemCount: bloc.senseBoxes.length,
            itemBuilder: (context, index) {
              final senseBox = bloc.senseBoxes[index];
              return ListTile(
                title: Text(senseBox['name'] ?? 'Unnamed senseBox'),
                subtitle: Text(senseBox['_id']),
                onTap: () {
                  SenseBox selectedSenseBox = SenseBox.fromJson(senseBox);
                  bloc.setSelectedSenseBox(selectedSenseBox);
                  Navigator.pop(context); // Go back after selecting
                },
              );
            },
          );
        },
      ),
    );
  }
}
