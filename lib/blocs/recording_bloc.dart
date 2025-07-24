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

  VoidCallback? _onRecordingStart;
  VoidCallback? _onRecordingStop;

  bool get isRecording => _isRecording;

  ValueNotifier<bool> get isRecordingNotifier => _isRecordingNotifier;

  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;

  RecordingBloc(this.isarService, this.bleBloc, this.trackBloc,
      this.openSenseMapBloc, this.settingsBloc) {
    openSenseMapBloc.senseBoxStream
        .listen(_onSenseBoxChanged).onError((error) {
      ErrorService.handleError(error, StackTrace.current);
    }); 

    // Listen to permanent BLE connection loss and stop recording
    bleBloc.permanentConnectionLossNotifier
        .addListener(_onPermanentConnectionLoss);
  }

  void _onPermanentConnectionLoss() {
    if (_isRecording) {
      stopRecording();
    }
  }

  void setRecordingCallbacks({
    VoidCallback? onRecordingStart,
    VoidCallback? onRecordingStop,
  }) {
    _onRecordingStart = onRecordingStart;
    _onRecordingStop = onRecordingStop;
  }

  void _onSenseBoxChanged(SenseBox? senseBox) {
    _selectedSenseBox = senseBox;
    notifyListeners(); 
  }

  void startRecording() async {
    if (_isRecording) return;

    _isRecording = true;
    _isRecordingNotifier.value = true; 
    await trackBloc.startNewTrack();

    _currentTrack = trackBloc.currentTrack;

    try {
      if (_selectedSenseBox == null) {
        ErrorService.handleError(NoSenseBoxSelected(), StackTrace.current,
            sendToSentry: false);
        notifyListeners();
        return;
      }

      _directUploadService = DirectUploadService(
          openSenseMapService: OpenSenseMapService(),
          settingsBloc: settingsBloc,
          senseBox: _selectedSenseBox!);

      _onRecordingStart?.call();

    } catch (e, stack) {
      ErrorService.handleError(e, stack);
    }

    notifyListeners();
  }

  void stopRecording() async {
    if (!_isRecording) return;

    _isRecording = false;
    _isRecordingNotifier.value = false;
    _onRecordingStop?.call();
    _directUploadService?.dispose();
    _directUploadService = null;
    _currentTrack = null;

    notifyListeners();
  }

  DirectUploadService? get directUploadService => _directUploadService;

  @override
  void dispose() {
    bleBloc.permanentConnectionLossNotifier
        .removeListener(_onPermanentConnectionLoss);
    _directUploadService?.dispose();
    _isRecordingNotifier.dispose();
    super.dispose();
  }
}
