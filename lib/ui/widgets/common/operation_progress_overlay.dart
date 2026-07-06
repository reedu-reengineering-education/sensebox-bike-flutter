import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay_config.dart';

export 'package:sensebox_bike/ui/widgets/common/operation_progress_overlay_config.dart';

class OperationProgressOverlay {
  static bool _isVisible = false;
  static NavigatorState? _navigator;
  static bool _isHidingProgrammatically = false;

  static void show(
    BuildContext context, {
    required OperationProgressOverlayConfig config,
  }) {
    if (_isVisible) return;
    _isVisible = true;
    _navigator = Navigator.maybeOf(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OperationProgressModal(
        progressStream: config.progressStream,
        showConfirmation: config.showConfirmation,
        titleText: config.titleText,
        confirmMessageText: config.confirmMessageText,
        onComplete: () {
          OperationProgressOverlay.hide();
          config.onComplete?.call();
        },
        onFailed: config.onFailed,
        onStart: config.onStart,
        onDismiss: () {
          if (!_isHidingProgrammatically) {
            config.onDismiss?.call();
          }
        },
      ),
    ).whenComplete(_resetState);
  }

  static void hide() {
    if (_isVisible) {
      _isVisible = false;
      if (_navigator != null) {
        _isHidingProgrammatically = true;
        if (_navigator!.canPop()) {
          _navigator!.pop();
        }
        _navigator = null;
        scheduleMicrotask(() {
          _isHidingProgrammatically = false;
        });
      }
    }
  }

  static void _resetState() {
    _isVisible = false;
    _navigator = null;
    _isHidingProgrammatically = false;
  }

  static bool get isVisible => _isVisible;
}
