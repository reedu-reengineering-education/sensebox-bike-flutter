import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/track/export_button.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/ui/widgets/track/upload_status_indicator.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/sensor_tile_list.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:intl/intl.dart';

class TrackDetailScreen extends StatefulWidget {
  final TrackData track;

  const TrackDetailScreen({super.key, required this.track});

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

  _TrackDetailScreenState();

  @override
  void initState() {
    super.initState();
    isarService = Provider.of<TrackBloc>(context, listen: false).isarService;
    openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context, listen: false);
    
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
    super.dispose();
  }

  Widget _buildUploadStatusSection() {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: padding),
      padding: const EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload,
                size: iconSizeLarge,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: spacing / 2),
              Text(
                localizations.uploadProgressTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              UploadStatusIndicator(
                track: widget.track,
                onRetryPressed: _isUploading ? null : _startUpload,
                showText: true,
                isCompact: false,
              ),
            ],
          ),
          const SizedBox(height: spacing / 2),
          _buildUploadDetails(),
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
        if (widget.track.uploadAttempts > 0) ...[
          _buildDetailRow(
            icon: Icons.refresh,
            label: 'Upload attempts',
            value: widget.track.uploadAttempts.toString(),
            theme: theme,
          ),
          const SizedBox(height: spacing / 4),
        ],
        if (widget.track.lastUploadAttempt != null) ...[
          _buildDetailRow(
            icon: Icons.schedule,
            label: 'Last attempt',
            value: DateFormat('dd.MM.yyyy HH:mm').format(widget.track.lastUploadAttempt!),
            theme: theme,
          ),
          const SizedBox(height: spacing / 4),
        ],
        if (widget.track.uploaded) ...[
          _buildDetailRow(
            icon: Icons.check_circle,
            label: 'Status',
            value: localizations.trackStatusUploaded,
            theme: theme,
            valueColor: Colors.green,
          ),
        ] else if (widget.track.uploadAttempts > 0) ...[
          _buildDetailRow(
            icon: Icons.error,
            label: 'Status',
            value: localizations.trackStatusUploadFailed,
            theme: theme,
            valueColor: theme.colorScheme.error,
          ),
        ] else ...[
          _buildDetailRow(
            icon: Icons.pending,
            label: 'Status',
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
      final geolocations = await isarService.geolocationService
          .getGeolocationDataWithPreloadedSensors(widget.track.id);
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

  Future<void> _handleAndroidExport(String csvFilePath) async {
    final localization = AppLocalizations.of(context)!;

    try {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;

      // check if api level is smaller than 33
      if (androidInfo.version.sdkInt < 33) {
        PermissionStatus status = await Permission.storage.request();

        if (!status.isGranted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(localization.trackDetailsPermissionsError),
            action: SnackBarAction(
                label: localization.generalSettings,
                onPressed: () => openAppSettings()),
          ));
          return;
        }
      }

      Directory? directory;

      if (defaultTargetPlatform == TargetPlatform.android) {
        //downloads folder - android only - API>30
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null || !directory.existsSync()) {
        ErrorService.handleError(
            ExportDirectoryAccessError(), StackTrace.current);
        return;
      }

      // copy file to external storage
      final file = File(csvFilePath);
      final newName = file.path.split('/').last;
      final newPath = '${directory.path}/$newName';

      await file.copy(newPath);

      if (context.mounted) {
        // show snackbar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localization.trackDetailsFileSaved),
          action: SnackBarAction(
            label: localization.generalShare,
            onPressed: () async {
              await _shareFile(newPath);
            },
          ),
        ));
      }
    } catch (e) {
      await _shareFile(csvFilePath);
    }
  }

  Future<void> _exportTrackToCsv(
      {bool isOpenSourceMapCompatible = false}) async {
    setState(() => _isDownloading = true);

    try {
      final String csvFilePath;

      if (isOpenSourceMapCompatible) {
        csvFilePath =
            await isarService
            .exportTrackToCsvInOpenSenseMapFormat(widget.track.id);
      } else {
        csvFilePath = await isarService.exportTrackToCsv(widget.track.id);
      }

      // if android, save to external storage
      // if ios, open share dialog
      if (Platform.isAndroid) {
        _handleAndroidExport(csvFilePath);
      } else if (Platform.isIOS) {
        await Share.shareXFiles([XFile(csvFilePath)],
            text: AppLocalizations.of(context)!.trackDetailsExport);
      }
    } catch (e) {
      ErrorService.handleError('Error exporting CSV: $e', StackTrace.current);
    } finally {
      setState(() {
        _isDownloading = false; 
      });
    }
  }

  Future<void> _startUpload() async {
    final localizations = AppLocalizations.of(context)!;
    
    // Check if user is authenticated
    if (!openSenseMapBloc.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.uploadProgressAuthenticationError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Check if senseBox is selected
    if (openSenseMapBloc.selectedSenseBox == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.errorNoSenseBoxSelected),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Show upload progress modal
      UploadProgressOverlay.show(
        context,
        batchUploadService: batchUploadService,
        onUploadComplete: () {
          // Upload completed successfully
          setState(() => _isUploading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.trackUploadRetrySuccess),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh the track data to show updated status
            setState(() {});
          }
        },
        onUploadFailed: () {
          // Upload failed permanently
          setState(() => _isUploading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.trackUploadRetryFailed),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        onRetryRequested: () {
          // User requested retry - restart upload with fresh service
          _retryUpload();
        },
      );

      // Start the upload
      await batchUploadService.uploadTrack(
          widget.track, openSenseMapBloc.selectedSenseBox!);
    } catch (e) {
      setState(() => _isUploading = false);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.trackUploadRetryFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _retryUpload() async {
    final localizations = AppLocalizations.of(context)!;

    // Check if user is authenticated
    if (!openSenseMapBloc.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.uploadProgressAuthenticationError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Check if senseBox is selected
    if (openSenseMapBloc.selectedSenseBox == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.errorNoSenseBoxSelected),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Reset the batch upload service to start fresh
      batchUploadService.dispose();
      batchUploadService = BatchUploadService(
        openSenseMapService: openSenseMapBloc.openSenseMapService,
        trackService: isarService.trackService,
        openSenseMapBloc: openSenseMapBloc,
      );

      // Show upload progress modal with fresh service
      UploadProgressOverlay.show(
        context,
        batchUploadService: batchUploadService,
        onUploadComplete: () {
          // Upload completed successfully
          setState(() => _isUploading = false);
          if (mounted) {
            setState(() {});
          }
        },
        onUploadFailed: () {
          // Upload failed permanently
          setState(() => _isUploading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.trackUploadRetryFailed),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        onRetryRequested: () {
          // User requested retry again
          _retryUpload();
        },
      );

      // Start the upload with fresh service
      await batchUploadService.uploadTrack(
          widget.track, openSenseMapBloc.selectedSenseBox!);
    } catch (e) {
      setState(() => _isUploading = false);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.trackUploadRetryFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildAppBarTitle(TrackData track) {
    String errorMessage = AppLocalizations.of(context)!.trackDetailsNoData;
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          trackName(track, errorMessage: errorMessage),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        // Only show buttons if track has geolocations
        if (_geolocations.isNotEmpty) ...[
          // Upload button - only show if track hasn't been uploaded
          if (!track.uploaded)
            GestureDetector(
              onTap: _isUploading ? null : _startUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.cloud_upload,
                        size: 20,
                        color: theme.colorScheme.onSurface,
                      ),
              ),
            ),
          ExportButton(
            isDisabled: false,
            isDownloading: _isDownloading,
            onExport: (selectedFormat) async {
              if (selectedFormat == 'regular') {
                await _exportTrackToCsv();
              } else if (selectedFormat == 'openSenseMap') {
                await _exportTrackToCsv(isOpenSourceMapCompatible: true);
              }
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(widget.track)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_geolocations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(widget.track)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.trackDetailsNoData),
        ),
      );
    }

    final minSensorValue =
        getMinSensorValue(_geolocations, _sensorType).toStringAsFixed(1);
    final maxSensorValue =
        getMaxSensorValue(_geolocations, _sensorType).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle(widget.track)),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
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
            // Upload status section
            _buildUploadStatusSection(),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(children: [
                  Container(
                      height: 12,
                      decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(20),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Colors.green,
                              Colors.orange,
                              Colors.red,
                            ], // Gradient from https://learnui.design/tools/gradient-generator.html
                            tileMode: TileMode.mirror,
                          ))),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(minSensorValue),
                    const Spacer(),
                    Text(maxSensorValue)
                  ])
                ])),
            SensorTileList(
              sensorData: _sensorData,
              selectedSensorType: _sensorType,
              onSensorTypeSelected: (type) {
                setState(() {
                  _sensorType = type;
                });
              },
            )
          ],
        ),
      ),
    );
  }
}
