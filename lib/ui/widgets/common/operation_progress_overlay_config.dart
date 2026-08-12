import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';

class OperationProgressOverlayConfig {
  final Stream<UploadProgress> progressStream;
  final bool showConfirmation;
  final String? titleText;
  final String? confirmMessageText;
  final VoidCallback? onComplete;
  final VoidCallback? onFailed;
  final VoidCallback? onStart;
  final VoidCallback? onDismiss;
  final String? exportFilePath;
  final Future<void> Function()? onShare;

  const OperationProgressOverlayConfig._({
    required this.progressStream,
    required this.showConfirmation,
    this.titleText,
    this.confirmMessageText,
    this.onComplete,
    this.onFailed,
    this.onStart,
    this.onDismiss,
    this.exportFilePath,
    this.onShare,
  });

  factory OperationProgressOverlayConfig.upload({
    required BatchUploadService uploadService,
    String? titleText,
    String? confirmMessageText,
    VoidCallback? onComplete,
    VoidCallback? onFailed,
    VoidCallback? onStart,
    VoidCallback? onDismiss,
  }) {
    return OperationProgressOverlayConfig._(
      progressStream: uploadService.uploadProgressStream,
      showConfirmation: true,
      titleText: titleText,
      confirmMessageText: confirmMessageText,
      onComplete: onComplete,
      onFailed: onFailed,
      onStart: onStart,
      onDismiss: onDismiss,
    );
  }

  factory OperationProgressOverlayConfig.stream({
    required Stream<UploadProgress> progressStream,
    bool showConfirmation = false,
    String? titleText,
    String? confirmMessageText,
    VoidCallback? onComplete,
    VoidCallback? onFailed,
    VoidCallback? onStart,
    VoidCallback? onDismiss,
    String? exportFilePath,
    Future<void> Function()? onShare,
  }) {
    return OperationProgressOverlayConfig._(
      progressStream: progressStream,
      showConfirmation: showConfirmation,
      titleText: titleText,
      confirmMessageText: confirmMessageText,
      onComplete: onComplete,
      onFailed: onFailed,
      onStart: onStart,
      onDismiss: onDismiss,
      exportFilePath: exportFilePath,
      onShare: onShare,
    );
  }
}
