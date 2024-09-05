// File: lib/blocs/track_bloc.dart

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class TrackBloc with ChangeNotifier {
  final IsarService isarService;
  TrackData? _currentTrack;

  TrackBloc(this.isarService);

  TrackData? get currentTrack => _currentTrack;

  void startNewTrack() {
    _currentTrack = TrackData();
    isarService.trackService.saveTrack(_currentTrack!);
    notifyListeners();
  }

  void endTrack() {
    _currentTrack = null;
    notifyListeners();
  }
}