import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

    if (bloc.senseBoxes.isEmpty) {
      _fetchSenseBoxes();
    }
  }

  void _fetchSenseBoxes() {
    if (isLoading || !hasMore) return;
    setState(() {
      isLoading = true;
    });

    bloc.fetchSenseBoxes(page: page).then((values) {
      if (!mounted) return; // Ensure the widget is still in the tree

      setState(() {
        isLoading = false;
        page++;

        // Stop loading if no more senseBoxes are found
        if (values.isEmpty) {
          hasMore = false;
        }
      });
    }).catchError((error) {
      if (!mounted) return; // Ensure the widget is still in the tree

      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching senseBoxes: $error');
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
                Text(
                    AppLocalizations.of(context)!
                        .openSenseMapBoxSelectionNoBoxes,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(AppLocalizations.of(context)!
                    .openSenseMapBoxSelectionCreateHint),
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
            final isSenseBoxBikeCompatible =
                bloc.isSenseBoxBikeCompatible(senseBox);

            return ListTile(
              title: Text(senseBox.name ??
                  AppLocalizations.of(context)!
                      .openSenseMapBoxSelectionUnnamedBox),
              subtitle: !isSenseBoxBikeCompatible
                  ? Row(
                      children: [
                        Icon(
                          Icons.warning,
                          size: 12,
                        ),
                        SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!
                            .openSenseMapBoxSelectionIncompatible),
                      ],
                    )
                  : senseBox.grouptag != null && senseBox.grouptag!.isNotEmpty
                      ? Wrap(
                          spacing: 8,
                          children: senseBox.grouptag!
                              .map((tag) => Badge(
                                    label: Text(tag),
                                    backgroundColor:
                                        Theme.of(context).iconTheme.color,
                                  ))
                              .toList(),
                        )
                      : null,
              trailing: isSelected
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              enabled: isSenseBoxBikeCompatible,
              onTap: isSenseBoxBikeCompatible
                  ? () async {
                      await bloc.setSelectedSenseBox(senseBox);
                      if (context.mounted) {
                        Navigator.pop(context); // Go back after selecting
                      }
                    }
                  : null,
            );
          },
        );
      },
    );
  }
}
