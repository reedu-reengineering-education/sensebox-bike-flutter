import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/error_service.dart';

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
  final _scrollController = ScrollController();
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<OpenSenseMapBloc>().senseBoxes.isEmpty) {
        _fetchSenseBoxes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels == position.maxScrollExtent) {
      _fetchSenseBoxes();
    }
  }

  Future<void> _fetchSenseBoxes() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final boxes =
        await context.read<OpenSenseMapBloc>().fetchSenseBoxes(page: _page);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _page++;
      _hasMore = boxes.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<OpenSenseMapBloc>();
    final boxes = bloc.senseBoxes.map((e) => SenseBox.fromJson(e)).toList();

    if (boxes.isEmpty) {
      return _isLoading
          ? _buildLoadingSkeleton()
          : _buildEmptyState(isAuthenticated: bloc.isAuthenticated);
    }
    return _buildBoxList(bloc, boxes);
  }

  Widget _buildBoxList(OpenSenseMapBloc bloc, List<SenseBox> boxes) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onTileColor = theme.colorScheme.onTertiaryContainer;

    return ListView.builder(
      controller: _scrollController,
      itemCount: boxes.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == boxes.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final senseBox = boxes[index];
        final isSelected = senseBox.id == bloc.selectedSenseBox?.id;
        final grouptags = senseBox.grouptag ?? [];

        return Material(
          color: Colors.transparent,
          child: ListTile(
            title: Text(
              senseBox.name ?? localizations.openSenseMapBoxSelectionUnnamedBox,
              style: theme.textTheme.bodyLarge?.copyWith(color: onTileColor),
            ),
            subtitle: grouptags.isEmpty
                ? null
                : Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in grouptags)
                        Badge(
                          label: Text(tag),
                          textColor: onTileColor,
                          backgroundColor: onTileColor.withValues(alpha: 0.14),
                        ),
                    ],
                  ),
            trailing: isSelected ? Icon(Icons.check, color: onTileColor) : null,
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              unawaited(bloc
                  .setSelectedSenseBox(isSelected ? null : senseBox)
                  .catchError((Object error, StackTrace stackTrace) =>
                      ErrorService.handleError(
                          'Error selecting senseBox: $error', stackTrace)));
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool isAuthenticated}) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final configurationBloc = widget.configurationBloc;
    final isConfigurationLoaded = configurationBloc.boxConfigurations != null &&
        !configurationBloc.isLoadingBoxConfigurations;
    final hintText = !isAuthenticated
        ? localizations.trackUploadLoginSelectHint
        : isConfigurationLoaded
            ? localizations.openSenseMapBoxSelectionCreateHint
            : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bike, size: 48, color: onSurface),
            const SizedBox(height: 16),
            Text(
              localizations.openSenseMapBoxSelectionNoBoxes,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (hintText != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  hintText,
                  style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.onSurface.withValues(alpha: 0.10);

    Widget line(double width, double height) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: lineColor,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        key: const ValueKey('sensebox-loading-skeleton-item'),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(180, 14),
            const SizedBox(height: 10),
            line(120, 10),
          ],
        ),
      ),
    );
  }
}
