import 'dart:async';

import 'package:flutter/foundation.dart';
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

typedef BatchUploadPromptHandler = Future<void> Function({
  required TrackData track,
  required SenseBox? senseBox,
  required BatchUploadService batchUploadService,
  required VoidCallback onFinished,
});

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
  Future<void> Function()? _onRecordingStoppedDueToBle;
  BatchUploadPromptHandler? _onBatchUploadPrompt;

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

  void setUiCallbacks({
    Future<void> Function()? onRecordingStoppedDueToBle,
    BatchUploadPromptHandler? onBatchUploadPrompt,
  }) {
    _onRecordingStoppedDueToBle = onRecordingStoppedDueToBle;
    _onBatchUploadPrompt = onBatchUploadPrompt;
  }

  void clearUiCallbacks() {
    _onRecordingStoppedDueToBle = null;
    _onBatchUploadPrompt = null;
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
    _batchUploadService = null;

    final shouldPromptBatchUpload = !_directUploadMode &&
        batchUploadService != null &&
        trackToUpload != null &&
        _onBatchUploadPrompt != null;

    if (!shouldPromptBatchUpload) {
      batchUploadService?.dispose();
    }

    if (dueToBleDisconnect) {
      await _onRecordingStoppedDueToBle?.call();
    }

    if (shouldPromptBatchUpload) {
      await _onBatchUploadPrompt!(
        track: trackToUpload,
        senseBox: senseBoxForUpload,
        batchUploadService: batchUploadService!,
        onFinished: () {},
      );
    }
  }

  void dispose() {
    bleBloc.connectionErrorNotifier.removeListener(_onBleConnectionError);
    clearUiCallbacks();
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

  void _disposeDirectUploadService() {
    _directUploadService?.dispose();
    _directUploadService = null;
  }

  void _disposeBatchUploadService() {
    _batchUploadService?.dispose();
    _batchUploadService = null;
  }
}
