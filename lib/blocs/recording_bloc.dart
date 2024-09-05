import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class RecordingBloc with ChangeNotifier {
  final BleBloc bleBloc;
  final IsarService isarService;
  final TrackBloc trackBloc;

  bool _isRecording = false;
  TrackData? _currentTrack;

  bool get isRecording => _isRecording;
  TrackData? get currentTrack => _currentTrack;

  RecordingBloc(this.isarService, this.bleBloc, this.trackBloc) {
    bleBloc.addListener(_onBluetoothConnectionChanged);
  }

  void _onBluetoothConnectionChanged() {
    if (!bleBloc.isConnected && _isRecording) {
      stopRecording();
    }
  }

  void startRecording() {
    if (_isRecording) return;

    _isRecording = true;
    trackBloc.startNewTrack();

    _currentTrack = trackBloc.currentTrack;

    notifyListeners();
  }

  void stopRecording() {
    if (!_isRecording) return;

    _isRecording = false;

    // trackBloc.endTrack();

    _currentTrack = null;

    notifyListeners();
  }

  @override
  void dispose() {
    bleBloc.removeListener(_onBluetoothConnectionChanged);
    super.dispose();
  }
}
