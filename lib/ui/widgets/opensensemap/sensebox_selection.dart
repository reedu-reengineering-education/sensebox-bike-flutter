import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/error_service.dart';
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
  static const _errorIcon = Icons.error_outline;
  
  late final OpenSenseMapBloc _bloc;
  bool isLoading = false;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<OpenSenseMapBloc>();

    if (_bloc.senseBoxes.isEmpty) {
      _fetchSenseBoxes();
    }
  }

  void _updateLoadingState({String? error}) {
    if (!mounted) return;
    setState(() {
      isLoading = false;
      _fetchError = error;
    });
  }

  void _fetchSenseBoxes() {
    isLoading = true;
    if (mounted) {
      setState(() {});
    }

    _bloc.fetchSenseBoxes().then((values) {
      _updateLoadingState();
    }).catchError((error) {
      _updateLoadingState(error: error.toString());
      ErrorService.handleError(
          'Error fetching senseBoxes: $error', StackTrace.current);
    });
  }

  @override
  Widget build(BuildContext context) {
    final configurationBloc = widget.configurationBloc;
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<OpenSenseMapBloc>(
      builder: (context, bloc, child) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (_fetchError != null) {
          return ErrorMessage(
            icon: _errorIcon,
            title: localizations.openSenseMapBoxSelectionNoBoxes,
            detail: _fetchError,
          );
        }

        if (bloc.senseBoxes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_bike, size: 48),
                const SizedBox(height: 16),
                Text(
                    localizations.openSenseMapBoxSelectionNoBoxes,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(localizations.openSenseMapBoxSelectionCreateHint),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bloc.senseBoxes.length,
          itemBuilder: (context, index) {
            final senseBox = SenseBox.fromJson(bloc.senseBoxes[index]);
            final isSelected = senseBox.id == bloc.selectedSenseBox?.id;
            final isSenseBoxBikeCompatible =
                configurationBloc.isSenseBoxBikeCompatible(senseBox);

            return ListTile(
              title: Text(senseBox.name ??
                  localizations.openSenseMapBoxSelectionUnnamedBox),
              subtitle: !isSenseBoxBikeCompatible
                  ? Row(
                      children: [
                        Icon(
                          Icons.warning,
                          size: 12,
                        ),
                        SizedBox(width: 8),
                        Text(
                            localizations.openSenseMapBoxSelectionIncompatible),
                      ],
                    )
                  : senseBox.grouptag != null && senseBox.grouptag!.isNotEmpty
                      ? Wrap(
                          spacing: 8,
                          children: senseBox.grouptag!
                              .map((tag) => Badge(
                                    label: Text(tag),
                                    backgroundColor: theme.iconTheme.color,
                                  ))
                              .toList(),
                        )
                      : null,
              trailing: isSelected
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
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
