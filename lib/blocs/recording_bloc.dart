// File: lib/providers/recording_state_provider.dart

import 'package:sensebox_bike/models/track_data.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class RecordingBloc with ChangeNotifier {
  bool _isRecording = false;
  final IsarService isarService;
  TrackData? _currentTrack;

  RecordingBloc(this.isarService);

  bool get isRecording => _isRecording;

  void startRecording() {
    _isRecording = true;
    _currentTrack = TrackData();
    isarService.saveTrack(_currentTrack!);
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    _currentTrack = null;
    notifyListeners();
  }

  void toggleRecording() {
    if (_isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  }

  TrackData? get currentTrack => _currentTrack;
}
