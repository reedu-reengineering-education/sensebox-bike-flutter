import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/direct_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_dialog.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay.dart';
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

  DataCollectionMode _activeCollectionMode = DataCollectionMode.gpsDriven;
  int _collectionIntervalSeconds = defaultCollectionIntervalSeconds;
  final ValueNotifier<DataCollectionMode> activeCollectionModeNotifier =
      ValueNotifier<DataCollectionMode>(DataCollectionMode.gpsDriven);

  Future<void> Function()? _onRecordingStart;
  Future<void> Function()? _onRecordingStop;

  // Context for showing upload modal
  BuildContext? _context;
  DateTime? _lastRecordingStopTimestamp;

  bool get isRecording => _isRecording;

  ValueNotifier<bool> get isRecordingNotifier => _isRecordingNotifier;

  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;
  DateTime? get lastRecordingStopTimestamp => _lastRecordingStopTimestamp;

  DataCollectionMode get activeCollectionMode => _activeCollectionMode;
  int get collectionIntervalSeconds => _collectionIntervalSeconds;

  RecordingBloc(
    this.isarService,
    this.bleBloc,
    this.trackBloc,
    this.openSenseMapBloc,
    this.settingsBloc,
  ) {
    openSenseMapBloc.senseBoxStream.listen(_onSenseBoxChanged).onError((error) {
      ErrorService.handleError(error, StackTrace.current);
    });

    // Listen to BLE connection errors and stop recording
    bleBloc.connectionErrorNotifier.addListener(_onBleConnectionError);
    settingsBloc.addListener(_onSettingsChanged);
  }

  void _onBleConnectionError() {
    if (_isRecording) {
      // Stop recording will automatically trigger batch upload if needed
      stopRecording();
    }
  }

  void _onSettingsChanged() {
    if (!_isRecording) return;
    _activeCollectionMode = settingsBloc.dataCollectionMode;
    _collectionIntervalSeconds = settingsBloc.collectionIntervalSeconds;
    activeCollectionModeNotifier.value = _activeCollectionMode;
    notifyListeners();
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
    Future<void> Function()? onRecordingStop,
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
      await PermissionService.ensureLocationPermissionsGranted(
        requireAlways: true,
      );
    } on LocationPermissionDenied catch (e) {
      // Show confirmation modal before redirecting user to app settings
      if (_context != null) {
        final localizations = AppLocalizations.of(_context!);
        final message = ErrorService.parseError(e, _context!);
        final proceedToSettings = await showCustomDialog(
          context: _context!,
          message: message,
          type: DialogType.confirmation,
          confirmButtonText: localizations?.generalGoToSettings,
        );
        if (proceedToSettings == true) {
          await PermissionService.openAppSettings();
        }
      }
      notifyListeners();
      return;
    } catch (e) {
      ErrorService.handleError(e, StackTrace.current);
      notifyListeners();
      return;
    }

    _activeCollectionMode = settingsBloc.dataCollectionMode;
    _collectionIntervalSeconds = settingsBloc.collectionIntervalSeconds;
    activeCollectionModeNotifier.value = _activeCollectionMode;
    _isRecording = true;
    _lastRecordingStopTimestamp = null;
    await trackBloc.startNewTrack(
      isDirectUpload: settingsBloc.directUploadMode,
      dataCollectionMode: _activeCollectionMode,
      collectionIntervalSeconds: _activeCollectionMode.usesPeriodicTimer
          ? _collectionIntervalSeconds
          : null,
    );

    _currentTrack = trackBloc.currentTrack;
    _isRecordingNotifier.value = true;

    try {
      if (_selectedSenseBox == null && settingsBloc.directUploadMode) {
        await trackBloc.updateDirectUploadAuthFailure(_currentTrack!);
        ErrorService.handleError(NoSenseBoxSelected(), StackTrace.current,
            sendToSentry: false);
        notifyListeners();
        return;
      }

      if (settingsBloc.directUploadMode) {
        _directUploadService = DirectUploadService(
            openSenseMapService: OpenSenseMapService(),
            senseBox: _selectedSenseBox!,
            openSenseMapBloc: openSenseMapBloc,
            onUploadFailed: _onDirectUploadFailed);
      } else {
        _batchUploadService = BatchUploadService(
          openSenseMapService: openSenseMapBloc.openSenseMapService,
          trackService: isarService.trackService,
          openSenseMapBloc: openSenseMapBloc,
        );
      }

      await _onRecordingStart?.call();
    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }

    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _lastRecordingStopTimestamp = DateTime.now().toUtc();

    _isRecording = false;
    _isRecordingNotifier.value = false;
    // Keep activeCollectionMode until the next startRecording snapshots
    // settings. Resetting to gpsDriven made the idle GPS stream take the
    // continuous persist path and race into the first on-tap/periodic point.
    await _onRecordingStop?.call();

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
        trackToUpload != null &&
        _context != null) {
      _showUploadProgressModal(trackToUpload, senseBoxForUpload);
    } else {
      // For direct upload mode, dispose the batch upload service
      _batchUploadService?.dispose();
      _batchUploadService = null;
    }

    notifyListeners();
  }

  void _showUploadProgressModal(TrackData track, SenseBox? senseBox) async {
    if (_context == null || _batchUploadService == null) return;

    final canUpload =
        senseBox != null && openSenseMapBloc.hasAuthAndSelectedSenseBox;

    if (!canUpload) {
      final localizations = AppLocalizations.of(_context!);
      final message = !openSenseMapBloc.isAuthenticated
          ? localizations?.uploadBlockNotAuthenticated
          : localizations?.uploadBlockNoBox;

      if (message != null) {
        showCustomDialog(
          context: _context!,
          message: message,
          confirmButtonText: localizations?.generalOk,
          type: DialogType.confirmation,
        );
      }

      _cleanupBatchUploadService();
      return;
    }

    try {
      await track.geolocations.load();
      final geolocations = track.geolocations.toList();

      if (geolocations.isEmpty) {
        throw TrackHasNoGeolocationsException(track.id);
      }

      OperationProgressOverlay.show(
        _context!,
        config: OperationProgressOverlayConfig.upload(
          uploadService: _batchUploadService!,
          onComplete: () {
            _cleanupBatchUploadService();
            debugPrint('[RecordingBloc] Batch upload completed successfully');
          },
          onFailed: () {
            _cleanupBatchUploadService();
            debugPrint('[RecordingBloc] Batch upload failed permanently');
          },
          onStart: () {
            _startBatchUpload(track, senseBox);
          },
        ),
      );
    } catch (e, stack) {
      debugPrint('[RecordingBloc] Error showing upload modal: $e');
      ErrorService.handleError(e, stack);
      OperationProgressOverlay.hide();
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
    settingsBloc.removeListener(_onSettingsChanged);
    _directUploadService?.dispose();
    _batchUploadService?.dispose();
    _isRecordingNotifier.dispose();
    activeCollectionModeNotifier.dispose();

    // Hide any open upload modal
    OperationProgressOverlay.hide();

    super.dispose();
  }
}
