import 'package:flutter/material.dart';

class RecordingStateProvider with ChangeNotifier {
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

  void toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
  }
}
