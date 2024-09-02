import 'package:flutter/material.dart';

class RecordingState with ChangeNotifier {
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }
}
