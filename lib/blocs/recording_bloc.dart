import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';

class RecordingBloc {
  final BleBloc bleBloc;
  final IsarService isarService;
  final TrackBloc trackBloc;
  final OpenSenseMapBloc openSenseMapBloc;
  final SettingsBloc settingsBloc;

  TrackData? _currentTrack;
  DirectUploadService? _directUploadService;
  BatchUploadService? _batchUploadService;

  VoidCallback? _onRecordingStop;
  Future<void> Function()? _onRecordingStartAsync;

  BuildContext? _context;
  DateTime? _lastRecordingStopTimestamp;

  final ValueNotifier<bool> isRecordingNotifier = ValueNotifier(false);

  bool get isRecording => isRecordingNotifier.value;
  bool get _directUploadMode => settingsBloc.directUploadMode;

  TrackData? get currentTrack => _currentTrack;
  DateTime? get lastRecordingStopTimestamp => _lastRecordingStopTimestamp;

  DirectUploadService? get directUploadService => _directUploadService;
  BatchUploadService? get batchUploadService => _batchUploadService;

  RecordingBloc(
    this.isarService,
    this.bleBloc,
    this.trackBloc,
    this.openSenseMapBloc,
    this.settingsBloc,
  ) {
    bleBloc.connectionErrorNotifier.addListener(_onBleConnectionError);
  }

  void setRecordingCallbacks({
    Future<void> Function()? onRecordingStart,
    VoidCallback? onRecordingStop,
  }) {
    _onRecordingStartAsync = onRecordingStart;
    _onRecordingStop = onRecordingStop;
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  Future<void> startRecording() async {
    if (isRecording) {
      return;
    }

    try {
      await PermissionService.ensureLocationPermissionsForRecording();
      await PermissionService.ensureNotificationPermissionGranted();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
      return;
    }

    if (!bleBloc.isReadyForRecording) {
      ErrorService.handleError(
        BleNotReadyForRecording(),
        StackTrace.current,
        sendToSentry: false,
      );
      return;
    }

    DirectUploadService? directUploadService;
    BatchUploadService? batchUploadService;
    int? trackId;

    try {
      trackId = await trackBloc.startNewTrack(isDirectUpload: _directUploadMode);
      _currentTrack = trackBloc.currentTrack;

      if (_directUploadMode && openSenseMapBloc.selectedSenseBox == null) {
        await trackBloc.updateDirectUploadAuthFailure(_currentTrack!);
        throw NoSenseBoxSelected();
      }

      final uploadServices = _createUploadServices();
      directUploadService = uploadServices.directUploadService;
      batchUploadService = uploadServices.batchUploadService;

      isRecordingNotifier.value = true;
      _lastRecordingStopTimestamp = null;
      _directUploadService = directUploadService;
      _batchUploadService = batchUploadService;

      await _onRecordingStartAsync?.call();
    } catch (e, stack) {
      await _rollbackRecordingStart(
        trackId: trackId ?? _currentTrack?.id,
        directUploadService: directUploadService,
        batchUploadService: batchUploadService,
      );

      ErrorService.handleError(
        e,
        stack,
        sendToSentry: e is! NoSenseBoxSelected,
      );
    }
  }

  Future<void> stopRecording({bool dueToBleDisconnect = false}) async {
    if (!isRecording) {
      return;
    }

    _lastRecordingStopTimestamp = DateTime.now().toUtc();
    isRecordingNotifier.value = false;
    _onRecordingStop?.call();

    final trackToUpload = _currentTrack;
    final senseBoxForUpload = openSenseMapBloc.selectedSenseBox;
    final batchUploadService = _batchUploadService;

    _disposeDirectUploadService();
    _currentTrack = null;

    final shouldShowUploadModal = !_directUploadMode &&
        batchUploadService != null &&
        trackToUpload != null &&
        _context != null;

    if (shouldShowUploadModal) {
      _batchUploadService = batchUploadService;
    } else {
      _disposeBatchUploadService();
    }

    if (dueToBleDisconnect) {
      await _showRecordingStoppedDueToBleDialog();
    }

    if (shouldShowUploadModal && (_context?.mounted ?? false)) {
      await _showUploadProgressModal(trackToUpload, senseBoxForUpload);
    }
  }

  void dispose() {
    bleBloc.connectionErrorNotifier.removeListener(_onBleConnectionError);
    _disposeDirectUploadService();
    _disposeBatchUploadService();
    isRecordingNotifier.dispose();
    UploadProgressOverlay.hide();
  }

  void _onBleConnectionError() {
    if (bleBloc.connectionErrorNotifier.value && isRecording) {
      stopRecording(dueToBleDisconnect: true);
    }
  }

  void _onDirectUploadFailed() {
    final track = _currentTrack;
    if (track == null) {
      return;
    }

    trackBloc.updateDirectUploadAuthFailure(track);
    ErrorService.handleError(
      DirectUploadFailureError(),
      StackTrace.current,
      sendToSentry: false,
    );
  }

  ({
    DirectUploadService? directUploadService,
    BatchUploadService? batchUploadService,
  }) _createUploadServices() {
    if (_directUploadMode) {
      return (
        directUploadService: DirectUploadService(
          openSenseMapService: OpenSenseMapService(),
          senseBox: openSenseMapBloc.selectedSenseBox!,
          openSenseMapBloc: openSenseMapBloc,
          onUploadFailed: _onDirectUploadFailed,
        ),
        batchUploadService: null,
      );
    }

    return (
      directUploadService: null,
      batchUploadService: BatchUploadService(
        openSenseMapService: openSenseMapBloc.openSenseMapService,
        trackService: isarService.trackService,
        openSenseMapBloc: openSenseMapBloc,
      ),
    );
  }

  Future<void> _rollbackRecordingStart({
    int? trackId,
    DirectUploadService? directUploadService,
    BatchUploadService? batchUploadService,
  }) async {
    isRecordingNotifier.value = false;
    _lastRecordingStopTimestamp = null;

    directUploadService?.dispose();
    batchUploadService?.dispose();
    _directUploadService = null;
    _batchUploadService = null;

    final id = trackId ?? _currentTrack?.id;
    if (id != null && id != 0) {
      await isarService.trackService.deleteTrack(id);
    }

    _currentTrack = null;
    trackBloc.endTrack();
  }

  Future<void> _showRecordingStoppedDueToBleDialog() async {
    final context = _context;
    if (context == null || !context.mounted) {
      return;
    }

    await showRecordingStoppedDueToBleDialog(context);
  }

  Future<void> _showUploadProgressModal(
    TrackData track,
    SenseBox? senseBox,
  ) async {
    final context = _context;
    final batchUploadService = _batchUploadService;
    if (context == null || batchUploadService == null) {
      return;
    }

    final canUpload =
        senseBox != null && openSenseMapBloc.hasAuthAndSelectedSenseBox;

    try {
      await track.geolocations.load();
      if (track.geolocations.isEmpty) {
        throw TrackHasNoGeolocationsException(track.id);
      }

      UploadProgressOverlay.show(
        context,
        batchUploadService: batchUploadService,
        canUpload: canUpload,
        isAuthenticated: openSenseMapBloc.isAuthenticated,
        hasSelectedBox: openSenseMapBloc.selectedSenseBox != null,
        onUploadComplete: () {
          _disposeBatchUploadService();
          debugPrint('[RecordingBloc] Batch upload completed successfully');
        },
        onUploadFailed: () {
          _disposeBatchUploadService();
          debugPrint('[RecordingBloc] Batch upload failed permanently');
        },
        onStartUpload: () {
          if (canUpload) {
            unawaited(_uploadTrack(track, senseBox!, batchUploadService));
          }
        },
      );
    } catch (e, stack) {
      debugPrint('[RecordingBloc] Error showing upload modal: $e');
      ErrorService.handleError(e, stack);
      UploadProgressOverlay.hide();
      _disposeBatchUploadService();
    }
  }

  Future<void> _uploadTrack(
    TrackData track,
    SenseBox senseBox,
    BatchUploadService batchUploadService,
  ) async {
    try {
      await batchUploadService.uploadTrack(track, senseBox);
    } catch (e, stack) {
      ErrorService.handleError(
        'Batch upload failed after recording stop: $e',
        stack,
        sendToSentry: true,
      );
    }
  }

  void _disposeDirectUploadService() {
    _directUploadService?.dispose();
    _directUploadService = null;
  }

  void _disposeBatchUploadService() {
    _batchUploadService?.dispose();
    _batchUploadService = null;
  }
}
