import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

Future<void> vibrateDisconnectFeedback() async {
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
