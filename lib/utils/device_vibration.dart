import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:vibration/vibration.dart';

/// Disconnect alert routed per platform:
/// - iOS: [Vibration] (worked reliably before the BLE refactor)
/// - Android: [Haptics] with notification-class routing (works on current devices)
Future<void> vibrateDisconnectFeedback() async {
  if (Platform.isIOS) {
    await _vibrateIos();
    return;
  }
  await _vibrateAndroid();
}

/// Light tap feedback for primary UI actions (connect, start/stop, etc.).
///
/// Uses [Haptics] (native UIImpact/selection) instead of Flutter's
/// [HapticFeedback], which is unreliable on many iOS devices.
/// No-ops on hardware without a taptic engine (most iPads, simulator).
Future<void> vibrateTapFeedback() async {
  try {
    if (await Haptics.canVibrate()) {
      await Haptics.vibrate(HapticsType.selection);
      return;
    }
  } on PlatformException catch (e) {
    debugPrint('vibrateTapFeedback: $e');
  }

  // Fallbacks when the preferred path is unavailable.
  if (Platform.isIOS) {
    try {
      if (await Vibration.hasVibrator() == true) {
        await Vibration.vibrate(duration: 15);
        return;
      }
    } on PlatformException catch (e) {
      debugPrint('vibrateTapFeedback iOS fallback: $e');
    }
  }

  await HapticFeedback.selectionClick();
}

Future<void> _vibrateIos() async {
  try {
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate();
      return;
    }
  } on PlatformException catch (e) {
    debugPrint('vibrateDisconnectFeedback iOS: $e');
  }
  await HapticFeedback.heavyImpact();
}

Future<void> _vibrateAndroid() async {
  if (!(await Haptics.canVibrate())) {
    debugPrint('vibrateDisconnectFeedback: device reports no vibrator');
    return;
  }

  try {
    await Haptics.vibrate(
      HapticsType.heavy,
      useAndroidHapticConstants: true,
      usage: HapticsUsage.notification,
    );
  } on PlatformException catch (e) {
    debugPrint('vibrateDisconnectFeedback: $e');
    try {
      await Haptics.vibrate(HapticsType.heavy);
    } on PlatformException catch (e2) {
      debugPrint('vibrateDisconnectFeedback fallback: $e2');
    }
  }
}
