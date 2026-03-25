import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  State<SenseBoxSelectionWidget> createState() =>
      _SenseBoxSelectionWidgetState();
}

class _SenseBoxSelectionWidgetState extends State<SenseBoxSelectionWidget> {
  static const _errorIcon = Icons.error_outline;
  static const int _initialPage = 0;
  
  late final OpenSenseMapBloc _bloc;
  late ScrollController _scrollController;
  int page = _initialPage;
  bool isLoading = false;
  bool hasMore = true;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<OpenSenseMapBloc>();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bloc.senseBoxes.isEmpty) {
        _resetPagination();
        _fetchSenseBoxes();
      }
    });
  }

  void _resetPagination() {
    page = _initialPage;
    hasMore = true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
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

  bool _isAuthenticationError(String error) {
    return error.contains('Not authenticated') ||
        error.contains('Authentication failed') ||
        error.contains('No refresh token found') ||
        error.contains('Refresh token is expired');
  }

  void _fetchSenseBoxes() {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
      _fetchError = null;
    });

    _bloc.fetchSenseBoxes(page: page).then((values) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        page++;
        if (values.isEmpty) {
          hasMore = false;
        }
      });
    }).catchError((error) {
      if (!mounted) return;

      if (_isAuthenticationError(error.toString())) {
        _bloc.markAuthenticationFailed();
      }

      setState(() {
        isLoading = false;
        _fetchError = error.toString();
      });
      ErrorService.handleError(
          'Error fetching senseBoxes: $error', StackTrace.current);
    });
  }

  Widget _buildContent(BuildContext context, OpenSenseMapBloc bloc) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configurationBloc = widget.configurationBloc;

    if (isLoading && bloc.senseBoxes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_fetchError != null && bloc.senseBoxes.isEmpty) {
      return ErrorMessage(
        icon: _errorIcon,
        title: localizations.openSenseMapBoxSelectionNoBoxes,
        detail: _fetchError,
      );
    }

    if (bloc.senseBoxes.isEmpty && !isLoading) {
      return bloc.isAuthenticated
          ? _buildEmptyState(localizations, theme, configurationBloc)
          : ErrorMessage(
              icon: _errorIcon,
              title: localizations.openSenseMapBoxSelectionNoBoxes,
              detail: 'Please login to view your senseBoxes',
            );
    }

    return _buildBoxList(
        context, bloc, localizations, theme, configurationBloc);
  }

  Widget _buildBoxList(
      BuildContext context,
      OpenSenseMapBloc bloc,
      AppLocalizations localizations,
      ThemeData theme,
      ConfigurationBloc configurationBloc) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: bloc.senseBoxes.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == bloc.senseBoxes.length && isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (index == bloc.senseBoxes.length) {
          return const SizedBox();
        }

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
                    const Icon(Icons.warning, size: 12),
                    const SizedBox(width: 8),
                    Text(localizations.openSenseMapBoxSelectionIncompatible),
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpenSenseMapBloc, OpenSenseMapState>(
      builder: (context, state) => _buildContent(context, _bloc),
    );
  }

  Widget _buildEmptyState(AppLocalizations localizations, ThemeData theme,
      ConfigurationBloc configurationBloc) {
    final isConfigurationLoaded = configurationBloc.boxConfigurations != null &&
        !configurationBloc.isLoadingBoxConfigurations;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bike, size: 48),
            const SizedBox(height: 16),
            Text(localizations.openSenseMapBoxSelectionNoBoxes,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (isConfigurationLoaded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  localizations.openSenseMapBoxSelectionCreateHint,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
