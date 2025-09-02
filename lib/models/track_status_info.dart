import 'package:flutter/material.dart';

enum TrackStatus {
  directUpload,
  uploaded,
  uploadFailed,
  notUploaded,
  directUploadAuthFailed,
}

class TrackStatusInfo {
  final TrackStatus status;
  final Color color;
  final IconData icon;
  final String text;

  const TrackStatusInfo({
    required this.status,
    required this.color,
    required this.icon,
    required this.text,
  });
}
