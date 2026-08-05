

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
import 'package:sensebox_bike/ui/widgets/track/export_button.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay.dart';
import 'package:sensebox_bike/services/export_progress_service.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/sensor_tile_list.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:intl/intl.dart';
import 'package:sensebox_bike/ui/widgets/common/sensor_gradient_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/info_banner.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';
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
  // Local track data that can be updated
  late TrackData _track;

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
    batchUploadService.dispose();
    _exportProgressService?.dispose();
    super.dispose();
  }

  bool _shouldHideUploadButton() {
    final openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    final uploadEligible = openSenseMapBloc.hasAuthAndSelectedSenseBox;

    return !uploadEligible;
  }

  bool _shouldShowUploadHint() {
    final settingsBloc = Provider.of<SettingsBloc>(context, listen: false);
    final openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    final isPostRideMode = !settingsBloc.directUploadMode;
    final uploadEligible = openSenseMapBloc.hasAuthAndSelectedSenseBox;

    return isPostRideMode && !uploadEligible && _track.uploaded != 1;
  }

  Widget _buildUploadStatusSection() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_track.isDirectUploadTrack && _track.lastUploadAttempt == null) {
      // For direct upload tracks
      return InfoBanner(text: localizations.trackDirectUploadInfo);
    } else if (_track.isUploaded || _track.uploadAttemptsCount == 0) {
      // If uploaded, show only status icon (not collapsible)
      return Padding(
        padding:
            const EdgeInsets.symmetric(vertical: padding, horizontal: spacing),
        child: _buildStatusIcon(context, localizations, theme),
      );
    } else {
      // Otherwise, show collapsible
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: padding),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: spacing),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          collapsedBackgroundColor: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          title: _buildStatusIcon(context, localizations, theme),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: spacing),
              child: _buildUploadDetails(),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildStatusIcon(
      BuildContext context, AppLocalizations localizations, ThemeData theme) {
    final statusColor = _getStatusColor(theme);
    final statusIcon = _getStatusIcon();
    final statusText = _getStatusText(localizations);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: spacing / 2, vertical: padding / 2),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(borderRadiusSmall),
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
                color: statusColor,
                fontWeight: FontWeight.w500,
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
      return theme.colorScheme.outline;
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
    if (display == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: padding, horizontal: spacing),
      child: _buildDetailRow(
        icon: display.icon,
        label: localizations.trackCollectionModeLabel,
        value: display.text,
        theme: theme,
      ),
    );
  }

  /// iPad: upload status and sampling frequency on one row. Phone: stacked.
  Widget _buildStatusAndCollectionHeader() {
    if (!context.isTablet) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUploadStatusSection(),
          _buildCollectionModeSection(),
        ],
      );
    }

    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final display = collectionModeDisplay(_track, localizations);
    final collectionMode = display == null
        ? null
        : _buildDetailRow(
            icon: display.icon,
            label: localizations.trackCollectionModeLabel,
            value: display.text,
            theme: theme,
          );

    // Direct-upload info banner stays full width; sampling frequency below.
    if (_track.isDirectUploadTrack && _track.lastUploadAttempt == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoBanner(text: localizations.trackDirectUploadInfo),
          if (collectionMode != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: padding, horizontal: spacing),
              child: collectionMode,
            ),
        ],
      );
    }

    // Failed uploads keep the collapsible details; sampling frequency beside it.
    if (!_track.isUploaded && _track.uploadAttemptsCount > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: spacing),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                collapsedBackgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                title: _buildStatusIcon(context, localizations, theme),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: spacing),
                    child: _buildUploadDetails(),
                  ),
                ],
              ),
            ),
            if (collectionMode != null)
              Padding(
                padding: const EdgeInsets.only(
                    right: spacing, top: padding, left: spacing),
                child: collectionMode,
              ),
          ],
        ),
      );
    }

    // Uploaded / not-uploaded chip + sampling frequency inline.
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: padding, horizontal: spacing),
      child: Row(
        children: [
          Flexible(child: _buildStatusIcon(context, localizations, theme)),
          if (collectionMode != null) ...[
            const SizedBox(width: spacing),
            Flexible(child: collectionMode),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadDetails() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_track.uploadAttemptsCount > 0) ...[
          _buildDetailRow(
            icon: Icons.refresh,
            label: localizations.trackUploadAttempts,
            value: _track.uploadAttemptsCount.toString(),
            theme: theme,
          ),
          const SizedBox(height: spacing / 4),
        ],
        if (_track.lastUploadAttempt != null) ...[
          _buildDetailRow(
            icon: Icons.schedule,
            label: localizations.trackLastAttempt,
            value: DateFormat('dd.MM.yyyy HH:mm')
                .format(_track.lastUploadAttempt!),
            theme: theme,
          ),
          const SizedBox(height: spacing / 4),
        ],
        if (_track.isUploaded) ...[
          _buildDetailRow(
            icon: Icons.check_circle,
            label: localizations.trackStatus,
            value: localizations.trackStatusUploaded,
            theme: theme,
            valueColor: theme.colorScheme.success,
          ),
        ] else if (_track.uploadAttemptsCount > 0) ...[
          _buildDetailRow(
            icon: Icons.error,
            label: localizations.trackStatus,
            value: localizations.trackStatusUploadFailed,
            theme: theme,
            valueColor: theme.colorScheme.error,
          ),
        ] else ...[
          _buildDetailRow(
            icon: Icons.pending,
            label: localizations.trackStatus,
            value: localizations.trackStatusNotUploaded,
            theme: theme,
            valueColor: theme.colorScheme.outline,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: spacing / 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: spacing / 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      await Share.shareXFiles([XFile(filePath)],
          text: localization.trackDetailsExport);
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
            ErrorService.handleError('Error exporting CSV: $e', StackTrace.current);
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

  Widget _buildAppBarTitle(TrackData track, bool hideUploadButton) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          trackName(track),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Upload button - only show if track hasn't been uploaded
        if (!_track.isUploaded && !hideUploadButton)
          IconButton(
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            onPressed: _isUploading ? null : _startUpload,
          ),
        ExportButton(
          isDisabled: false,
          isDownloading: _isDownloading,
          onExport: (selectedFormat) async {
            // Require authentication for openSenseMap export format
            if (selectedFormat == 'openSenseMap' &&
                !openSenseMapBloc.isAuthenticated) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!
                          .exportRequiresLoginToOpenSenseMap,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              return;
            }

            if (selectedFormat == 'regular') {
              await _exportTrackToCsv();
            } else if (selectedFormat == 'openSenseMap') {
              await _exportTrackToCsv(isOpenSourceMapCompatible: true);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hideUploadButton = _shouldHideUploadButton();
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(_track, hideUploadButton)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle(_track, hideUploadButton)),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            _buildStatusAndCollectionHeader(),
            if (_shouldShowUploadHint())
              InfoBanner(text: localizations.trackUploadLoginSelectHint),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card.filled(
                  clipBehavior: Clip.hardEdge,
                  elevation: 4,
                  child: TrajectoryWidget(
                      geolocationData: _geolocations, sensorType: _sensorType),
                ),
              ),
            ),
            SensorGradientWidget(
              sensorType: _sensorType,
              geolocations: _geolocations,
              senseBox: openSenseMapBloc.selectedSenseBox,
            ),
            SensorTileList(
              sensorData: _sensorData,
              selectedSensorType: _sensorType,
              onSensorTypeSelected: (type) {
                setState(() {
                  _sensorType = type;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
