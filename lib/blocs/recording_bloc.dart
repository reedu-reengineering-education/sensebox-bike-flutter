import 'package:flutter/material.dart';
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
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';
import 'package:sensebox_bike/services/permission_service.dart';

class RecordingBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final IsarService isarService;
  final TrackBloc trackBloc;
  final OpenSenseMapBloc openSenseMapBloc;
  final SettingsBloc settingsBloc;

  bool _isRecording = false;
  TrackData? _currentTrack;
  SenseBox? _selectedSenseBox;
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  DirectUploadService? _directUploadService;
  BatchUploadService? _batchUploadService;

  VoidCallback? _onRecordingStop;
  Future<void> Function()? _onRecordingStartAsync;

  // Context for showing upload modal
  BuildContext? _context;
  DateTime? _lastRecordingStopTimestamp;

  bool get isRecording => _isRecording;

  ValueNotifier<bool> get isRecordingNotifier => _isRecordingNotifier;

  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  DateTime? get lastRecordingStopTimestamp => _lastRecordingStopTimestamp;

  RecordingBloc(this.isarService, this.bleBloc, this.trackBloc,
      this.openSenseMapBloc, this.settingsBloc) {
    openSenseMapBloc.senseBoxStream.listen(_onSenseBoxChanged).onError((error) {
      ErrorService.handleError(error, StackTrace.current);
    });

    // Listen to BLE connection errors and stop recording
    bleBloc.connectionErrorNotifier.addListener(_onBleConnectionError);
  }

  void _onBleConnectionError() {
    if (!bleBloc.connectionErrorNotifier.value || !_isRecording) {
      return;
    }

    stopRecording(dueToBleDisconnect: true);
  }

  void _onDirectUploadFailed() {
    if (_currentTrack != null) {
      trackBloc.updateDirectUploadAuthFailure(_currentTrack!);
      ErrorService.handleError(
        DirectUploadFailureError(),
        StackTrace.current,
        sendToSentry: false,
      );
    }
  }



  void setRecordingCallbacks({
    Future<void> Function()? onRecordingStart,
    VoidCallback? onRecordingStop,
  }) {
    _onRecordingStartAsync = onRecordingStart;
    _onRecordingStop = onRecordingStop;
  }

  /// Sets the context for showing upload modals
  void setContext(BuildContext context) {
    _context = context;
  }

  void _onSenseBoxChanged(SenseBox? senseBox) {
    _selectedSenseBox = senseBox;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      await PermissionService.ensureLocationPermissionsForRecording();
      await PermissionService.ensureNotificationPermissionGranted();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
      notifyListeners();
      return;
    }

    if (!bleBloc.isReadyForRecording) {
      ErrorService.handleError(
        BleNotReadyForRecording(),
        StackTrace.current,
        sendToSentry: false,
      );
      notifyListeners();
      return;
    }

    DirectUploadService? directUploadService;
    BatchUploadService? batchUploadService;
    int? trackId;

    try {
      trackId = await trackBloc.startNewTrack(
        isDirectUpload: settingsBloc.directUploadMode,
      );
      _currentTrack = trackBloc.currentTrack;

      if (_selectedSenseBox == null && settingsBloc.directUploadMode) {
        await trackBloc.updateDirectUploadAuthFailure(_currentTrack!);
        throw NoSenseBoxSelected();
      }

      if (settingsBloc.directUploadMode) {
        directUploadService = DirectUploadService(
          openSenseMapService: OpenSenseMapService(),
          senseBox: _selectedSenseBox!,
          openSenseMapBloc: openSenseMapBloc,
          onUploadFailed: _onDirectUploadFailed,
        );
      } else {
        batchUploadService = BatchUploadService(
          openSenseMapService: openSenseMapBloc.openSenseMapService,
          trackService: isarService.trackService,
          openSenseMapBloc: openSenseMapBloc,
        );
      }

      _isRecording = true;
      _isRecordingNotifier.value = true;
      _lastRecordingStopTimestamp = null;
      _directUploadService = directUploadService;
      _batchUploadService = batchUploadService;

      if (_onRecordingStartAsync != null) {
        await _onRecordingStartAsync!();
      }
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

    notifyListeners();
  }

  Future<void> _rollbackRecordingStart({
    int? trackId,
    DirectUploadService? directUploadService,
    BatchUploadService? batchUploadService,
  }) async {
    _isRecording = false;
    _isRecordingNotifier.value = false;
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

  Future<void> stopRecording({bool dueToBleDisconnect = false}) async {
    if (!_isRecording) return;

    _lastRecordingStopTimestamp = DateTime.now().toUtc();

    _isRecording = false;
    _isRecordingNotifier.value = false;
    _onRecordingStop?.call();

    // Store current track and sensebox for upload
    final trackToUpload = _currentTrack;
    final senseBoxForUpload = _selectedSenseBox;

    // Clean up services and handle post-ride upload if needed
    _directUploadService?.dispose();
    _directUploadService = null;
    _currentTrack = null;

    final shouldShowUploadModal = !settingsBloc.directUploadMode &&
        _batchUploadService != null &&
        trackToUpload != null &&
        _context != null;

    if (!shouldShowUploadModal) {
      _batchUploadService?.dispose();
      _batchUploadService = null;
    }

    notifyListeners();

    if (dueToBleDisconnect) {
      await _showRecordingStoppedDueToBleDialog();
    }

    if (shouldShowUploadModal && (_context?.mounted ?? false)) {
      _showUploadProgressModal(trackToUpload, senseBoxForUpload);
    }
  }

  Future<void> _showRecordingStoppedDueToBleDialog() async {
    final context = _context;
    if (context == null || !context.mounted) {
      return;
    }

    await showRecordingStoppedDueToBleDialog(context);
  }

  void _showUploadProgressModal(TrackData track, SenseBox? senseBox) async {
    if (_context == null || _batchUploadService == null) return;

    final canUpload =
        senseBox != null && openSenseMapBloc.hasAuthAndSelectedSenseBox;

    try {
      await track.geolocations.load();
      final geolocations = track.geolocations.toList();

      if (geolocations.isEmpty) {
        throw TrackHasNoGeolocationsException(track.id);
      }

      UploadProgressOverlay.show(
        _context!,
        batchUploadService: _batchUploadService!,
        canUpload: canUpload,
        isAuthenticated: openSenseMapBloc.isAuthenticated,
        hasSelectedBox: openSenseMapBloc.selectedSenseBox != null,
        onUploadComplete: () {
          _cleanupBatchUploadService();
          debugPrint('[RecordingBloc] Batch upload completed successfully');
        },
        onUploadFailed: () {
          _cleanupBatchUploadService();
          debugPrint('[RecordingBloc] Batch upload failed permanently');
        },
        onStartUpload: () {
          if (canUpload) _startBatchUpload(track, senseBox!);
        },
      );
    } catch (e, stack) {
      debugPrint('[RecordingBloc] Error showing upload modal: $e');
      ErrorService.handleError(e, stack);
      UploadProgressOverlay.hide();
      _cleanupBatchUploadService();
    }
  }

  void _startBatchUpload(TrackData track, SenseBox senseBox) async {
    if (_batchUploadService == null) return;

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
  void _cleanupBatchUploadService() {
    _batchUploadService?.dispose();
    _batchUploadService = null;
  }

  DirectUploadService? get directUploadService => _directUploadService;
  BatchUploadService? get batchUploadService => _batchUploadService;

  @override
  void dispose() {
    bleBloc.connectionErrorNotifier.removeListener(_onBleConnectionError);
    _directUploadService?.dispose();
    _batchUploadService?.dispose();
    _isRecordingNotifier.dispose();

    // Hide any open upload modal
    UploadProgressOverlay.hide();

    super.dispose();
  }
}
