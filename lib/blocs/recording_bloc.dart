import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/live_upload_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

class RecordingBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final IsarService isarService;
  final TrackBloc trackBloc;
  final OpenSenseMapBloc openSenseMapBloc;

  bool _isRecording = false;
  TrackData? _currentTrack;
  SenseBox? _selectedSenseBox;

  bool get isRecording => _isRecording;
  TrackData? get currentTrack => _currentTrack;
  SenseBox? get selectedSenseBox => _selectedSenseBox;

  RecordingBloc(
      this.isarService, this.bleBloc, this.trackBloc, this.openSenseMapBloc) {
    bleBloc.addListener(_onBluetoothConnectionChanged);
    openSenseMapBloc.senseBoxStream
        .listen(_onSenseBoxChanged); // Listen to senseBoxStream
  }

  void _onBluetoothConnectionChanged() {
    if (!bleBloc.isConnected && _isRecording) {
      stopRecording();
    }
  }

  void _onSenseBoxChanged(SenseBox? senseBox) {
    _selectedSenseBox = senseBox;
    notifyListeners(); // If you want to notify listeners when the senseBox changes
  }

  void startRecording() async {
    if (_isRecording) return;

    _isRecording = true;
    await trackBloc.startNewTrack();

    _currentTrack = trackBloc.currentTrack;

    try {
      if (_selectedSenseBox == null) {
        throw Exception("No senseBox selected");
      }

      LiveUploadService liveUploadService = LiveUploadService(
          openSenseMapService: OpenSenseMapService(),
          senseBox:
              _selectedSenseBox!, // Use the cached value of selectedSenseBox
          trackId: trackBloc.currentTrack!.id);

      liveUploadService.startUploading();
    } catch (e) {
      print("Error while uploading: $e");
    }

    notifyListeners();
  }

  void stopRecording() {
    if (!_isRecording) return;

    _isRecording = false;
    _currentTrack = null;

    notifyListeners();
  }

  @override
  void dispose() {
    bleBloc.removeListener(_onBluetoothConnectionChanged);
    super.dispose();
  }
}
