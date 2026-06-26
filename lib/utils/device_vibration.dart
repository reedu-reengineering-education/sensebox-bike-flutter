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
