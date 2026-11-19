import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

Future<void> vibrateDisconnectFeedback() async {
  try {
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate();
      return;
    }
  } on PlatformException catch (e) {
    debugPrint('vibrateDisconnectFeedback: $e');
  }
  await HapticFeedback.heavyImpact();
}
