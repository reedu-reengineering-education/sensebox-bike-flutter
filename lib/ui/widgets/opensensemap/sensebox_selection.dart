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
  late ScrollController _scrollController;

  int page = 0;
  bool isLoading = false;
  bool hasMore = true;

  @override
  void initState() {
    super.initState();
    bloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchSenseBoxes();
  }

  void _fetchSenseBoxes() {
    if (isLoading || !hasMore) return;
    setState(() {
      isLoading = true;
    });

    bloc.fetchSenseBoxes(page: page).then((values) {
      setState(() {
        isLoading = false;
        page++;

        // Stop loading if no more senseBoxes are found
        if (values.isEmpty) {
          hasMore = false;
        }
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchSenseBoxes();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OpenSenseMapBloc>(
      builder: (context, bloc, child) {
        if (bloc.senseBoxes.isEmpty && isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

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
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: bloc.senseBoxes.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == bloc.senseBoxes.length && isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (index == bloc.senseBoxes.length) {
              return const SizedBox(); // End of list
            }

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
          },
        );
      },
    );
  }
}
