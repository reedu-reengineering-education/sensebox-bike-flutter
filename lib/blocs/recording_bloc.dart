import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';

@immutable
class BatchUploadRequest {
  const BatchUploadRequest({
    required this.track,
    required this.senseBox,
    required this.canUpload,
    required this.createdAt,
  });

  final TrackData track;
  final SenseBox? senseBox;
  final bool canUpload;
  final DateTime createdAt;
}

@immutable
class RecordingState {
  const RecordingState({
    required this.isRecording,
    required this.currentTrack,
    required this.selectedSenseBox,
    required this.lastRecordingStopTimestamp,
    required this.pendingBatchUploadRequest,
  });

  final bool isRecording;
  final TrackData? currentTrack;
  final SenseBox? selectedSenseBox;
  final DateTime? lastRecordingStopTimestamp;
  final BatchUploadRequest? pendingBatchUploadRequest;
}

enum RecordingLifecycleEvent {
  started,
  stopped,
}

class RecordingBloc extends Cubit<RecordingState> {
  final BleBloc bleBloc;
  final IsarService isarService;
  final TrackBloc trackBloc;
  final OpenSenseMapBloc openSenseMapBloc;
  final SettingsBloc settingsBloc;
  final OpenSenseMapService openSenseMapService;

  bool _isRecording = false;
  TrackData? _currentTrack;
  SenseBox? _selectedSenseBox;
  DirectUploadService? _directUploadService;
  BatchUploadService? _batchUploadService;
  final StreamController<RecordingLifecycleEvent> _lifecycleController =
      StreamController<RecordingLifecycleEvent>.broadcast();
  StreamSubscription<BleState>? _bleStateSubscription;
  StreamSubscription<SenseBox?>? _senseBoxSubscription;

  DateTime? _lastRecordingStopTimestamp;
  BatchUploadRequest? _pendingBatchUploadRequest;

  bool get isRecording => _isRecording;
  Stream<bool> get isRecordingStream =>
      stream.map((state) => state.isRecording).distinct();
  Stream<RecordingLifecycleEvent> get lifecycleEvents =>
      _lifecycleController.stream;

  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  DateTime? get lastRecordingStopTimestamp => _lastRecordingStopTimestamp;
  BatchUploadRequest? get pendingBatchUploadRequest =>
      _pendingBatchUploadRequest;

  RecordingBloc(
    this.isarService,
    this.bleBloc,
    this.trackBloc,
    this.openSenseMapBloc,
    this.settingsBloc, {
    required this.openSenseMapService,
  }) : super(const RecordingState(
          isRecording: false,
          currentTrack: null,
          selectedSenseBox: null,
          lastRecordingStopTimestamp: null,
          pendingBatchUploadRequest: null,
        )) {
    _senseBoxSubscription = openSenseMapBloc.senseBoxStream.listen(
      _onSenseBoxChanged,
      onError: (Object error, StackTrace stackTrace) {
        ErrorService.handleError(error, stackTrace);
      },
    );

    // Stop recording on BLE connection error transitions.
    _bleStateSubscription = bleBloc.stream.listen((bleState) {
      if (bleState.connectionError) {
        _onBleConnectionError();
      }
    });
  }

  void _emitState() {
    if (!isClosed) {
      emit(RecordingState(
        isRecording: _isRecording,
        currentTrack: _currentTrack,
        selectedSenseBox: _selectedSenseBox,
        lastRecordingStopTimestamp: _lastRecordingStopTimestamp,
        pendingBatchUploadRequest: _pendingBatchUploadRequest,
      ));
    }
  }

  void _onBleConnectionError() {
    if (_isRecording) {
      // Stop recording will automatically trigger batch upload if needed
      stopRecording();
    }
  }

  void _onSenseBoxChanged(SenseBox? senseBox) {
    _selectedSenseBox = senseBox;
    _emitState();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      // Check location permissions before starting recording
      await PermissionService.ensureLocationPermissionsGranted();
    } catch (e) {
      // Don't start recording if location permissions are not granted
      ErrorService.handleError(e, StackTrace.current);
      _emitState();
      return;
    }

    _isRecording = true;
    _lastRecordingStopTimestamp = null;
    _pendingBatchUploadRequest = null;
    await trackBloc.startNewTrack(
        isDirectUpload: settingsBloc.directUploadMode);

    _currentTrack = trackBloc.currentTrack;

    try {
      if (_selectedSenseBox == null && settingsBloc.directUploadMode) {
        await trackBloc.updateDirectUploadAuthFailure(_currentTrack!);
        ErrorService.handleError(NoSenseBoxSelected(), StackTrace.current,
            sendToSentry: false);
        _emitState();
        return;
      }

      if (settingsBloc.directUploadMode) {
        _directUploadService = DirectUploadService(
            openSenseMapService: openSenseMapService,
            senseBox: _selectedSenseBox!,
            openSenseMapBloc: openSenseMapBloc);
      } else {
        _batchUploadService = BatchUploadService(
          openSenseMapService: openSenseMapService,
          trackService: isarService.trackService,
          openSenseMapBloc: openSenseMapBloc,
        );
      }

      _lifecycleController.add(RecordingLifecycleEvent.started);
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }

    _emitState();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _lastRecordingStopTimestamp = DateTime.now().toUtc();

    _isRecording = false;
    _lifecycleController.add(RecordingLifecycleEvent.stopped);

    // Store current track and sensebox for upload
    final trackToUpload = _currentTrack;
    final senseBoxForUpload = _selectedSenseBox;

    // Clean up services and handle post-ride upload if needed
    _directUploadService?.dispose();
    _directUploadService = null;
    _currentTrack = null;

    // Only show upload modal for batch upload mode (post-ride upload)
    if (!settingsBloc.directUploadMode &&
        _batchUploadService != null &&
        trackToUpload != null) {
      _prepareBatchUploadRequest(trackToUpload, senseBoxForUpload);
    } else {
      // For direct upload mode, dispose the batch upload service
      _batchUploadService?.dispose();
      _batchUploadService = null;
    }

    _emitState();
  }

  void _prepareBatchUploadRequest(TrackData track, SenseBox? senseBox) async {
    if (_batchUploadService == null) return;

    final canUpload =
        senseBox != null && openSenseMapBloc.hasAuthAndSelectedSenseBox;

    try {
      await track.geolocations.load();
      final geolocations = track.geolocations.toList();

      if (geolocations.isEmpty) {
        throw TrackHasNoGeolocationsException(track.id);
      }
      _pendingBatchUploadRequest = BatchUploadRequest(
        track: track,
        senseBox: senseBox,
        canUpload: canUpload,
        createdAt: DateTime.now().toUtc(),
      );
      _emitState();
    } catch (e, stack) {
      debugPrint('[RecordingBloc] Error showing upload modal: $e');
      ErrorService.handleError(e, stack);
      _cleanupBatchUploadService();
    }
  }

  void clearBatchUploadRequest() {
    _pendingBatchUploadRequest = null;
    _emitState();
  }

  Future<void> startBatchUpload(TrackData track, SenseBox? senseBox) async {
    if (_batchUploadService == null) return;
    if (senseBox == null) return;

    try {
      await _batchUploadService!.uploadTrack(track, senseBox);
    } catch (e, stack) {
      // Log error but don't prevent recording from stopping
      // The modal will show the error state and allow retry
      ErrorService.handleError(
        'Batch upload failed after recording stop: $e',
        stack,
        sendToSentry: true,
      );
    }
  }

  void onBatchUploadCompleted() {
    _cleanupBatchUploadService();
    debugPrint('[RecordingBloc] Batch upload completed successfully');
  }

  void onBatchUploadFailed() {
    _cleanupBatchUploadService();
    debugPrint('[RecordingBloc] Batch upload failed permanently');
  }

  void _cleanupBatchUploadService() {
    _batchUploadService?.dispose();
    _batchUploadService = null;
  }

  DirectUploadService? get directUploadService => _directUploadService;
  BatchUploadService? get batchUploadService => _batchUploadService;

  @override
  Future<void> close() async {
    await _bleStateSubscription?.cancel();
    await _senseBoxSubscription?.cancel();
    _directUploadService?.dispose();
    _batchUploadService?.dispose();

    await _lifecycleController.close();

    return super.close();
  }

  void dispose() {
    unawaited(close());
  }
}
