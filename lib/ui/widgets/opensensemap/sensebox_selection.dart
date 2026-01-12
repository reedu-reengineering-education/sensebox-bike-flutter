import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/common/error_message.dart';

class SenseBoxSelectionWidget extends StatefulWidget {
  final ConfigurationBloc configurationBloc;

  const SenseBoxSelectionWidget({
    super.key,
    required this.configurationBloc,
  });

  @override
  _SenseBoxSelectionWidgetState createState() =>
      _SenseBoxSelectionWidgetState();
}

class _SenseBoxSelectionWidgetState extends State<SenseBoxSelectionWidget> {
  late ScrollController _scrollController;

  int page = 0;
  bool isLoading = false;
  bool hasMore = true;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<OpenSenseMapBloc>();
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

    final bloc = context.read<OpenSenseMapBloc>();
    bloc.fetchSenseBoxes(page: page).then((values) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        page++;
        _fetchError = null;

        if (values.isEmpty) {
          hasMore = false;
        }
      });
    }).catchError((error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        _fetchError = error.toString();
      });
      ErrorService.handleError(
          'Error fetching senseBoxes: $error', StackTrace.current);
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
    final configurationBloc = widget.configurationBloc;
    final localizations = AppLocalizations.of(context)!;
    
    if (configurationBloc.boxConfigurationsError != null) {
      return ErrorMessage(
        icon: Icons.error_outline,
        title: localizations.boxConfigurationLoadError,
        detail: configurationBloc.boxConfigurationsError,
      );
    }
    
    if (configurationBloc.isLoadingBoxConfigurations ||
        configurationBloc.boxConfigurations == null) {
      return const Center(child: Loader());
    }
    
    return Consumer<OpenSenseMapBloc>(
      builder: (context, bloc, child) {

        if (bloc.senseBoxes.isEmpty && isLoading) {
          return const Center(child: Loader());
        }

        if (bloc.senseBoxes.isEmpty) {
          if (_fetchError != null) {
            return ErrorMessage(
              icon: Icons.error_outline,
              title:
                  AppLocalizations.of(context)!.openSenseMapBoxSelectionNoBoxes,
              detail: _fetchError,
            );
          }
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
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Loader()),
              );
            }

            if (index == bloc.senseBoxes.length) {
              return const SizedBox();
            }

            final senseBox = SenseBox.fromJson(bloc.senseBoxes[index]);
            final isSelected = senseBox.id == bloc.selectedSenseBox?.id;
            final isSenseBoxBikeCompatible =
                widget.configurationBloc.isSenseBoxBikeCompatible(senseBox);

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
                      if (isSelected) {
                        await bloc.setSelectedSenseBox(null);
                      } else {
                        await bloc.setSelectedSenseBox(senseBox);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
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
