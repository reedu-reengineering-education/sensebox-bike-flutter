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

  VoidCallback? _onRecordingStart;
  VoidCallback? _onRecordingStop;

  // Context for showing upload modal
  BuildContext? _context;

  bool get isRecording => _isRecording;

  ValueNotifier<bool> get isRecordingNotifier => _isRecordingNotifier;

  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;

  RecordingBloc(this.isarService, this.bleBloc, this.trackBloc,
      this.openSenseMapBloc, this.settingsBloc) {
    openSenseMapBloc.senseBoxStream.listen(_onSenseBoxChanged).onError((error) {
      ErrorService.handleError(error, StackTrace.current);
    });

    // Listen to permanent BLE connection loss and stop recording
    bleBloc.permanentConnectionLossNotifier
        .addListener(_onPermanentConnectionLoss);
  }

  void _onPermanentConnectionLoss() {
    if (_isRecording) {
      // Stop recording will automatically trigger batch upload if needed
      stopRecording();
    }
  }

  // Test method to expose permanent connection loss handling
  @visibleForTesting
  void testOnPermanentConnectionLoss() {
    _onPermanentConnectionLoss();
  }

  void setRecordingCallbacks({
    VoidCallback? onRecordingStart,
    VoidCallback? onRecordingStop,
  }) {
    _onRecordingStart = onRecordingStart;
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
      // Check location permissions before starting recording
      await PermissionService.ensureLocationPermissionsGranted();
    } catch (e) {
      // Don't start recording if location permissions are not granted
      ErrorService.handleError(e, StackTrace.current);
      notifyListeners();
      return;
    }

    _isRecording = true;
    _isRecordingNotifier.value = true;
    await trackBloc.startNewTrack();

    _currentTrack = trackBloc.currentTrack;

    try {
      if (_selectedSenseBox == null && settingsBloc.directUploadMode) {
        ErrorService.handleError(NoSenseBoxSelected(), StackTrace.current,
            sendToSentry: false);
        notifyListeners();
        return;
      }

      // Create upload services based on user's upload mode preference
      if (settingsBloc.directUploadMode) {
        // Direct upload mode: create DirectUploadService for real-time uploads
        _directUploadService = DirectUploadService(
            openSenseMapService: OpenSenseMapService(),
            settingsBloc: settingsBloc,
            senseBox: _selectedSenseBox!,
            openSenseMapBloc: openSenseMapBloc);
      } else {
        // Post-ride upload mode: only create BatchUploadService
        _batchUploadService = BatchUploadService(
          openSenseMapService: OpenSenseMapService(),
          trackService: isarService.trackService,
          openSenseMapBloc: openSenseMapBloc,
        );
      }

      _onRecordingStart?.call();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }

    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

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

    // Trigger batch upload if in post-ride upload mode
    if (_batchUploadService != null &&
        trackToUpload != null &&
        senseBoxForUpload != null &&
        _context != null) {
      // Show upload progress modal
      _showUploadProgressModal(trackToUpload, senseBoxForUpload);

      // Don't start upload immediately - wait for user confirmation
    } else {
      // Clean up BatchUploadService if not uploading
      _batchUploadService?.dispose();
      _batchUploadService = null;
    }

    notifyListeners();
  }

  /// Shows the upload progress modal and starts the batch upload
  void _showUploadProgressModal(TrackData track, SenseBox senseBox) async {
    if (_context == null || _batchUploadService == null) return;

    try {
      // Check if track has geolocations before showing upload modal
      await track.geolocations.load();
      final geolocations = track.geolocations.toList();

      if (geolocations.isEmpty) {
        throw TrackHasNoGeolocationsException(track.id);
      }

      // Show the upload progress modal
      UploadProgressOverlay.show(
        _context!,
        batchUploadService: _batchUploadService!,
        onUploadComplete: () {
          // Upload completed successfully
          _cleanupBatchUploadService();
          debugPrint('[RecordingBloc] Batch upload completed successfully');
        },
        onUploadFailed: () {
          // Upload failed permanently
          debugPrint('[RecordingBloc] Batch upload failed permanently');
        },
        onStartUpload: () {
          // Start the upload when user confirms
          _startBatchUpload(track, senseBox);
        },
      );

      // Don't start upload immediately - wait for user confirmation
    } catch (e, stack) {
      debugPrint('[RecordingBloc] Error showing upload modal: $e');
      ErrorService.handleError(e, stack);
      // Ensure modal is hidden if there was an error
      UploadProgressOverlay.hide();
    }
  }

  /// Starts the batch upload process
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



  /// Cleans up the batch upload service
  void _cleanupBatchUploadService() {
    _batchUploadService?.dispose();
    _batchUploadService = null;
  }

  DirectUploadService? get directUploadService => _directUploadService;
  BatchUploadService? get batchUploadService => _batchUploadService;

  @override
  void dispose() {
    bleBloc.permanentConnectionLossNotifier
        .removeListener(_onPermanentConnectionLoss);
    _directUploadService?.dispose();
    _batchUploadService?.dispose();
    _isRecordingNotifier.dispose();

    // Hide any open upload modal
    UploadProgressOverlay.hide();

    super.dispose();
  }
}
