import 'package:haptic_feedback/haptic_feedback.dart';

Future<void> vibrateDisconnectFeedback() => Haptics.vibrate(
      HapticsType.error,
      usage: HapticsUsage.hardwareFeedback,
    );
