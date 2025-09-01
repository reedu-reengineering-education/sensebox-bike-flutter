// File: lib/blocs/track_bloc.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/track_status_info.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class TrackBloc with ChangeNotifier {
  final IsarService isarService;
  TrackData? _currentTrack;

  // StreamController to manage track updates
  final StreamController<TrackData?> _currentTrackController =
      StreamController<TrackData?>.broadcast();

  TrackBloc(this.isarService);

  TrackData? get currentTrack => _currentTrack;

  // Use the controller's stream for currentTrackStream
  Stream<TrackData?> get currentTrackStream => _currentTrackController.stream;

  Future<int> startNewTrack({bool? isDirectUpload}) async {
    _currentTrack = TrackData();
    
    // Set isDirectUpload based on parameter if provided, otherwise use default (true)
    if (isDirectUpload != null) {
      _currentTrack!.isDirectUpload = isDirectUpload;
    }

    int id = await isarService.trackService.saveTrack(_currentTrack!);

    // Emit the new currentTrack value to the stream
    _currentTrackController.add(_currentTrack);

    notifyListeners();

    return id;
  }

  void endTrack() {
    _currentTrack = null;

    // Emit the null value to the stream
    _currentTrackController.add(_currentTrack);

    notifyListeners();
  }



  Color _getStatusColor(TrackStatus status, ThemeData theme) {
    switch (status) {
      case TrackStatus.directUpload:
        return Colors.blue;
      case TrackStatus.uploaded:
        return Colors.green;
      case TrackStatus.uploadFailed:
        return theme.colorScheme.error;
      case TrackStatus.notUploaded:
        return theme.colorScheme.outline;
    }
  }

  IconData _getStatusIcon(TrackStatus status) {
    switch (status) {
      case TrackStatus.directUpload:
        return Icons.cloud_sync;
      case TrackStatus.uploaded:
        return Icons.cloud_done;
      case TrackStatus.uploadFailed:
        return Icons.cloud_off;
      case TrackStatus.notUploaded:
        return Icons.cloud_upload;
    }
  }

  String _getStatusText(TrackStatus status, AppLocalizations localizations) {
    switch (status) {
      case TrackStatus.directUpload:
        return localizations.settingsUploadModeDirect;
      case TrackStatus.uploaded:
        return localizations.trackStatusUploaded;
      case TrackStatus.uploadFailed:
        return localizations.trackStatusUploadFailed;
      case TrackStatus.notUploaded:
        return localizations.trackStatusNotUploaded;
    }
  }

  String buildStaticMapboxUrl(BuildContext context, String encodedPolyline) {
    if (encodedPolyline.isEmpty) {
      return '';
    }

    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String style = isDarkMode ? 'dark-v11' : 'light-v11';
    String lineColor = isDarkMode ? 'fff' : '111';
    String polyline = Uri.encodeComponent(encodedPolyline);

    const double mapPreviewWidth = 140;
    const double mapPreviewHeight = 140;

    return 'https://api.mapbox.com/styles/v1/mapbox/$style/static/path-1+$lineColor-0.8($polyline)/auto/${mapPreviewWidth.toInt()}x${mapPreviewHeight.toInt()}';
  }

  String formatTrackDate(DateTime timestamp) {
    return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.year}';
  }

  String formatTrackTimeRange(DateTime startTime, DateTime endTime) {
    String start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    String end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  String formatTrackDuration(
      Duration duration, AppLocalizations localizations) {
    return localizations.generalTrackDurationShort(
      duration.inHours.toString(),
      duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
    );
  }

  String formatTrackDistance(double distance, AppLocalizations localizations) {
    return localizations.generalTrackDistance(distance.toStringAsFixed(2));
  }

  TrackStatusInfo getEstimatedTrackStatusInfo(
      TrackData track, ThemeData theme, AppLocalizations localizations) {
    final isDirectUpload = track.isDirectUploadTrack;
    final uploaded = track.isUploaded;
    final uploadAttempts = track.uploadAttemptsCount;

    final status = calculateTrackStatusFromValues(
        isDirectUpload, uploaded, uploadAttempts);

    return TrackStatusInfo(
      status: status,
      color: _getStatusColor(status, theme),
      icon: _getStatusIcon(status),
      text: _getStatusText(status, localizations),
    );
  }

  TrackStatus calculateTrackStatusFromValues(
      bool isDirectUpload, bool uploaded, int uploadAttempts) {
    // Handle corrupted negative uploadAttempts values by treating them as 0
    final normalizedUploadAttempts = uploadAttempts < 0 ? 0 : uploadAttempts;
    
    if (isDirectUpload) {
      return TrackStatus.directUpload;
    } else if (uploaded) {
      return TrackStatus.uploaded;
    } else if (normalizedUploadAttempts > 0) {
      return TrackStatus.uploadFailed;
    } else {
      return TrackStatus.notUploaded;
    }
  }

  // Dispose the StreamController when no longer needed
  @override
  void dispose() {
    _currentTrackController.close();
    super.dispose();
  }
}
