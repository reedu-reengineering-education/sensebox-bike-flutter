// File: lib/blocs/track_bloc.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';

class TrackBloc with ChangeNotifier {
  final IsarService isarService;
  TrackData? _currentTrack;

  // StreamController to manage track updates
  final StreamController<TrackData?> _currentTrackController =
      StreamController<TrackData?>.broadcast();

  TrackBloc(this.isarService);

  TrackData? get currentTrack => _currentTrack;

  // Use the controller's stream for currentTrackStream
  Stream<TrackData?> get currentTrackStream => _currentTrackController.stream;

  Future<int> startNewTrack({bool? isDirectUpload}) async {
    _currentTrack = TrackData();
    
    // Set isDirectUpload based on parameter if provided, otherwise use default (true)
    if (isDirectUpload != null) {
      _currentTrack!.isDirectUpload = isDirectUpload;
    }

    int id = await isarService.trackService.saveTrack(_currentTrack!);

    // Emit the new currentTrack value to the stream
    _currentTrackController.add(_currentTrack);

    notifyListeners();

    return id;
  }

  void endTrack() {
    _currentTrack = null;

    // Emit the null value to the stream
    _currentTrackController.add(_currentTrack);

    notifyListeners();
  }

  // Dispose the StreamController when no longer needed
  @override
  void dispose() {
    _currentTrackController.close();
    super.dispose();
  }
}
