import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay.dart';
import 'package:sensebox_bike/services/export_progress_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/sensor_tile_list.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_gradient_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/info_banner.dart';
import 'package:sensebox_bike/utils/data_collection_mode_ui.dart';

class TrackDetailScreen extends StatefulWidget {
  final TrackData track;
  final VoidCallback? onTrackUploaded; // Add callback for track upload

  const TrackDetailScreen({
    super.key,
    required this.track,
    this.onTrackUploaded, // Add parameter
  });

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  late final IsarService isarService;
  late final OpenSenseMapBloc openSenseMapBloc;
  late final BatchUploadService batchUploadService;
  bool _isDownloading = false;
  bool _isUploading = false;
  late String _sensorType = 'temperature';
  List<GeolocationData> _geolocations = [];
  List<SensorData> _sensorData = [];
  bool _isLoading = true;
  ExportProgressService? _exportProgressService;
  late TrackData _track;
  final ValueNotifier<int?> _chartHighlightIndex = ValueNotifier(null);

  _TrackDetailScreenState();

  @override
  void initState() {
    super.initState();
    isarService = Provider.of<TrackBloc>(context, listen: false).isarService;
    openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context, listen: false);

    // Initialize local track data
    _track = widget.track;

    // Initialize batch upload service
    batchUploadService = BatchUploadService(
      openSenseMapService: openSenseMapBloc.openSenseMapService,
      trackService: isarService.trackService,
      openSenseMapBloc: openSenseMapBloc,
    );

    _loadTrackData();
  }

  @override
  void dispose() {
    _chartHighlightIndex.dispose();
    batchUploadService.dispose();
    _exportProgressService?.dispose();
    super.dispose();
  }

  bool _shouldHideUploadButton() {
    final openSenseMapBloc =
        Provider.of<OpenSenseMapBloc>(context, listen: false);
    final uploadEligible = openSenseMapBloc.hasAuthAndSelectedSenseBox;

    return !uploadEligible;
  }

  bool _shouldShowUploadHint() {
    final settingsBloc = Provider.of<SettingsBloc>(context, listen: false);
    final openSenseMapBloc =
        Provider.of<OpenSenseMapBloc>(context, listen: false);
    final isPostRideMode = !settingsBloc.directUploadMode;
    final uploadEligible = openSenseMapBloc.hasAuthAndSelectedSenseBox;

    return isPostRideMode && !uploadEligible && _track.uploaded != 1;
  }

  // Returns a compact inline chip for the status bar row
  Widget _buildUploadStatusSection() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _buildStatusIcon(context, localizations, theme);
  }

  Widget _buildStatusIcon(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    final statusColor = _getStatusColor(theme);
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText(localizations);
    final chipBackground = Color.alphaBlend(
      statusColor.withValues(alpha: 0.2),
      theme.colorScheme.surfaceContainerHighest,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: spacing / 2, vertical: padding / 2),
        decoration: BoxDecoration(
          color: chipBackground,
          borderRadius: BorderRadius.circular(borderRadiusSmall),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.35),
          ),
        ),
        constraints: const BoxConstraints(
          minWidth: 0,
          maxWidth: double.infinity,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcon,
              size: iconSizeLarge,
              color: statusColor,
            ),
            const SizedBox(width: spacing / 2),
            Text(
              statusText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ThemeData theme) {
    if (_track.isUploaded) {
      return theme.colorScheme.success;
    } else if (_track.uploadAttemptsCount > 0) {
      return theme.colorScheme.error;
    } else {
      return theme.colorScheme.primaryFixedDim;
    }
  }

  IconData _getStatusIcon() {
    if (_track.isUploaded) {
      return Icons.cloud_done;
    } else if (_track.uploadAttemptsCount > 0) {
      return Icons.cloud_off;
    } else {
      return Icons.cloud_upload;
    }
  }

  String _getStatusText(AppLocalizations localizations) {
    if (_track.isUploaded) {
      return localizations.trackStatusUploadedAt(DateFormat('dd.MM.yyyy HH:mm')
          .format(_track.lastUploadAttempt ?? DateTime.now()));
    } else if (_track.uploadAttemptsCount > 0) {
      return localizations.trackStatusUploadFailed;
    } else {
      return localizations.trackStatusNotUploaded;
    }
  }

  Widget _buildCollectionModeSection() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final display = collectionModeDisplay(_track, localizations);
    if (display == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: spacing / 2, vertical: padding / 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(display.icon,
              size: iconSizeLarge, color: theme.colorScheme.onSurface),
          const SizedBox(width: spacing / 2),
          Text(display.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  Future<void> _loadTrackData() async {
    try {
      // Refresh track metadata from database to get updated upload status
      final refreshedTrack =
          await isarService.trackService.getTrackById(_track.id);
      if (refreshedTrack != null) {
        // Update the local _track with fresh data
        _track.uploaded = refreshedTrack.uploaded;
        _track.uploadAttempts = refreshedTrack.uploadAttempts;
        _track.lastUploadAttempt = refreshedTrack.lastUploadAttempt;
      }

      final geolocations = await isarService.geolocationService
          .getGeolocationDataWithPreloadedSensors(_track.id);
      setState(() {
        _geolocations = geolocations;
        _sensorData = getAllUniqueSensorData(geolocations);
        _sensorType = getFirstAvailableSensorType(_sensorData);
        _isLoading = false;
      });
    } catch (e) {
      ErrorService.handleError(
          'Error loading track data: $e', StackTrace.current);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareFile(String filePath) async {
    final localization = AppLocalizations.of(context)!;

    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(filePath)],
        text: localization.trackDetailsExport,
        sharePositionOrigin:
            box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );
    } catch (e) {
      ErrorService.handleError('Error sharing file: $e', StackTrace.current);
    }
  }

  Future<void> _exportTrackToCsv(
      {bool isOpenSourceMapCompatible = false}) async {
    final localizations = AppLocalizations.of(context)!;
    setState(() => _isDownloading = true);

    _exportProgressService?.dispose();
    _exportProgressService = ExportProgressService(
      isarService: isarService,
      trackId: _track.id,
      isOpenSourceMapCompatible: isOpenSourceMapCompatible,
    );
    _exportProgressService!.initialize();

    String? exportedFilePath;

    OperationProgressOverlay.show(
      context,
      config: OperationProgressOverlayConfig.stream(
        progressStream: _exportProgressService!.progressStream,
        titleText: localizations.trackDetailsExport,
        showConfirmation: false,
        exportFilePath: 'export', // Flag to indicate this is an export
        onShare: () async {
          final path = exportedFilePath;
          if (path != null) {
            await _shareFile(path);
          }
        },
        onStart: () async {
          try {
            exportedFilePath = await _exportProgressService!.startExport();
          } catch (e) {
            ErrorService.handleError(
                'Error exporting CSV: $e', StackTrace.current);
          }
        },
        onComplete: () async {
          setState(() => _isDownloading = false);
          _exportProgressService?.dispose();
          _exportProgressService = null;
        },
        onFailed: () {
          setState(() => _isDownloading = false);
        },
        onDismiss: () {
          setState(() => _isDownloading = false);
          _exportProgressService?.cancel();
          _exportProgressService?.dispose();
          _exportProgressService = null;
        },
      ),
    );
  }

  Future<void> _startUpload() async {
    final localizations = AppLocalizations.of(context)!;

    final hasAuthAndBox = openSenseMapBloc.hasAuthAndSelectedSenseBox;
    if (!hasAuthAndBox) {
      final message = !openSenseMapBloc.isAuthenticated
          ? localizations.uploadProgressAuthenticationError
          : localizations.errorNoSenseBoxSelected;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      OperationProgressOverlay.show(
        context,
        config: OperationProgressOverlayConfig.upload(
          uploadService: batchUploadService,
          onComplete: () {
            // Upload completed successfully
            setState(() => _isUploading = false);
            if (mounted) {
              // Refresh the track data to show updated status
              _loadTrackData();
              widget.onTrackUploaded?.call(); // Call the callback
            }
          },
          onFailed: () {
            // Upload failed permanently
            setState(() => _isUploading = false);
            if (mounted) {
              // Refresh the track data to show updated error status and upload attempts
              _loadTrackData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizations.trackUploadRetryFailed),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          onStart: () async {
            // Start the upload when user confirms
            try {
              await batchUploadService.uploadTrack(
                  _track, openSenseMapBloc.selectedSenseBox!);
            } catch (e) {
              setState(() => _isUploading = false);
              // Show error message and refresh track data
              if (mounted) {
                // Refresh the track data to show any status changes
                _loadTrackData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.trackUploadRetryFailed),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
          onDismiss: () {
            // User canceled the upload modal
            setState(() => _isUploading = false);
          },
        ),
      );

      // Don't start upload immediately - wait for user confirmation
    } catch (e) {
      setState(() => _isUploading = false);
      // Show error message and refresh track data
      if (mounted) {
        // Refresh the track data to show any status changes
        _loadTrackData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.trackUploadRetryFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<({GeolocationData geo, double value, int geoIndex})> _getChartData() {
    final result = <({GeolocationData geo, double value, int geoIndex})>[];
    for (int i = 0; i < _geolocations.length; i++) {
      final geo = _geolocations[i];
      for (final sensor in geo.sensorData) {
        if (buildCanonicalSensorKey(sensor.title, sensor.attribute) ==
            _sensorType) {
          result.add((geo: geo, value: sensor.value, geoIndex: i));
          break;
        }
      }
    }
    return result;
  }

  void _showMenu(
    BuildContext context,
    AppLocalizations localizations,
    bool hideUploadButton,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                spacing, spacing, spacing, spacing / 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: spacing / 2,
                  runSpacing: spacing / 2,
                  children: [
                    _buildUploadStatusSection(),
                    _buildCollectionModeSection(),
                  ],
                ),
                if (_shouldShowUploadHint()) ...[
                  const SizedBox(height: spacing / 2),
                  InfoBanner(text: localizations.trackUploadLoginSelectHint),
                ],
                const SizedBox(height: spacing / 2),
                const Divider(),
                if (!_track.isUploaded && !hideUploadButton)
                  ListTile(
                    leading: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    title: Text(localizations.generalUpload),
                    onTap: _isUploading
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            _startUpload();
                          },
                  ),
                ListTile(
                  leading: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download),
                  title: Text(localizations.trackDetailsExport),
                  onTap: _isDownloading
                      ? null
                      : () {
                          Navigator.pop(sheetCtx);
                          _exportTrackToCsv();
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(localizations.openSenseMapCsv),
                  onTap: _isDownloading
                      ? null
                      : () {
                          Navigator.pop(sheetCtx);
                          if (!openSenseMapBloc.isAuthenticated) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(localizations
                                    .exportRequiresLoginToOpenSenseMap),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                            return;
                          }
                          _exportTrackToCsv(isOpenSourceMapCompatible: true);
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final localizations = AppLocalizations.of(context)!;
    final hideUploadButton = _shouldHideUploadButton();
    final chartData = _getChartData();
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Map header (collapses to 120 on scroll) ──────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _MapHeaderDelegate(
              minHeight: 200,
              maxHeight: screenHeight * 0.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TrajectoryWidget(
                    geolocationData: _geolocations,
                    sensorType: _sensorType,
                    highlightGeoIndex: _chartHighlightIndex,
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leadingWidth: 56,
                        leading: Padding(
                          padding: const EdgeInsets.all(spacing / 2),
                          child: _OverlayButton(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back,
                                size: iconSizeLarge),
                          ),
                        ),
                        title: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('dd.MM.yyyy')
                                  .format(_geolocations.first.timestamp),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${DateFormat('HH:mm').format(_geolocations.first.timestamp)} – ${DateFormat('HH:mm').format(_geolocations.last.timestamp)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        centerTitle: true,
                        actions: [
                          Padding(
                            padding: const EdgeInsets.all(spacing / 2),
                            child: _OverlayButton(
                              onTap: () => _showMenu(
                                  context, localizations, hideUploadButton),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.more_vert,
                                      size: iconSizeLarge),
                                  if (!_track.isUploaded)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getStatusColor(
                                              Theme.of(context)),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              width: 1),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sensor chart + gradient legend in card ──────────────────────
          if (chartData.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(spacing, spacing, spacing, 0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: spacing / 2),
                        child: _SensorChart(
                          chartData: chartData
                              .map(
                                  (p) => (value: p.value, geoIndex: p.geoIndex))
                              .toList(),
                          color: getSensorColor(_sensorType),
                          onHighlight: (geoIndex) =>
                              _chartHighlightIndex.value = geoIndex,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            spacing, spacing / 4, spacing, spacing / 2),
                        child: SensorGradientWidget(
                          sensorType: _sensorType,
                          geolocations: _geolocations,
                          senseBox: openSenseMapBloc.selectedSenseBox,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (chartData.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(spacing, spacing, spacing, 0),
                child: SensorGradientWidget(
                  sensorType: _sensorType,
                  geolocations: _geolocations,
                  senseBox: openSenseMapBloc.selectedSenseBox,
                ),
              ),
            ),

          // ── Phenomena / sensor tile grid ──────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(spacing, 0, spacing, spacing),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: spacing / 2,
                crossAxisSpacing: spacing / 2,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate(
                SensorTileList.buildTileWidgets(
                  context,
                  SensorTileList.filteredEntries(_sensorData),
                  _sensorType,
                  (type) => setState(() {
                    _sensorType = type;
                    _chartHighlightIndex.value = null;
                  }),
                ),
              ),
            ),
          ),

          const SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

// ── Map header sliver delegate ────────────────────────────────────────────────

class _MapHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _MapHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_MapHeaderDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      child != oldDelegate.child;
}

// ── Floating overlay button (back / menu) ─────────────────────────────────────

class _OverlayButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _OverlayButton({required this.child, this.onTap});

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: cardBoxShadow,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: colorScheme.onSurface),
          child: child,
        ),
      ),
    );
  }
}

// ── Sensor chart ─────────────────────────────────────────────────────────────

class _SensorChart extends StatefulWidget {
  final List<({double value, int geoIndex})> chartData;
  final Color color;
  final ValueChanged<int?> onHighlight;

  const _SensorChart({
    required this.chartData,
    required this.color,
    required this.onHighlight,
  });

  @override
  State<_SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<_SensorChart> {
  int? _hoverIndex;

  void _handlePan(Offset localPos, double width) {
    if (widget.chartData.isEmpty) return;
    final t = (localPos.dx / width).clamp(0.0, 1.0);
    final idx = (t * (widget.chartData.length - 1))
        .round()
        .clamp(0, widget.chartData.length - 1);
    if (idx != _hoverIndex) {
      setState(() => _hoverIndex = idx);
      widget.onHighlight(widget.chartData[idx].geoIndex);
    }
  }

  void _endPan() {
    setState(() => _hoverIndex = null);
    widget.onHighlight(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = widget.chartData.map((p) => p.value).toList();
    final minV = values.reduce(min);
    final maxV = values.reduce(max);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: spacing),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanUpdate: (d) => _handlePan(d.localPosition, width),
          onPanEnd: (_) => _endPan(),
          onTapDown: (d) => _handlePan(d.localPosition, width),
          onTapUp: (_) => _endPan(),
          child: CustomPaint(
            size: const Size(double.infinity, 120),
            painter: _SensorChartPainter(
              values: values,
              min: minV,
              max: maxV,
              color: widget.color,
              hoverIndex: _hoverIndex,
              onSurface: theme.colorScheme.onSurface,
              surface: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
        );
      }),
    );
  }
}

class _SensorChartPainter extends CustomPainter {
  final List<double> values;
  final double min;
  final double max;
  final Color color;
  final int? hoverIndex;
  final Color onSurface;
  final Color surface;

  static const double _vPad = 12;

  _SensorChartPainter({
    required this.values,
    required this.min,
    required this.max,
    required this.color,
    required this.hoverIndex,
    required this.onSurface,
    required this.surface,
  });

  double _yForValue(double v, double h) {
    if (max == min) return h / 2;
    return _vPad + (1 - (v - min) / (max - min)) * (h - _vPad * 2);
  }

  Offset _point(int i, Size size) {
    final x = values.length == 1
        ? size.width / 2
        : i / (values.length - 1) * size.width;
    return Offset(x, _yForValue(values[i], size.height));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final pts = List.generate(values.length, (i) => _point(i, size));

    // ── filled area ──────────────────────────────────────────────────────────
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── line ─────────────────────────────────────────────────────────────────
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── hover cursor ─────────────────────────────────────────────────────────
    if (hoverIndex != null) {
      final p = pts[hoverIndex!];
      final v = values[hoverIndex!];

      // Vertical guide line
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..color = onSurface.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );

      // Circle: white fill + sensor color stroke
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = surface
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);

      // Value pill above the circle
      final label = v.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      const pillH = 20.0;
      final pillW = tp.width + 12;
      var pillX = p.dx - pillW / 2;
      pillX = pillX.clamp(0, size.width - pillW);
      final pillY = (p.dy - pillH - 6).clamp(0.0, size.height - pillH);

      final pillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(pillX, pillY, pillW, pillH), const Radius.circular(6));
      canvas.drawRRect(pillRect, Paint()..color = surface);
      canvas.drawRRect(
          pillRect,
          Paint()
            ..color = onSurface.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      tp.paint(canvas, Offset(pillX + 6, pillY + (pillH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_SensorChartPainter old) =>
      old.hoverIndex != hoverIndex ||
      old.values != values ||
      old.color != color;
}
