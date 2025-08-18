import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    setUp(() {
      // Reset all feature flags to their default values before each test
      FeatureFlags.hideSurfaceAnomalySensor = true;
      FeatureFlags.showPrivacyPolicyScreen = false;
      FeatureFlags.enableLiveUpload = false;
    });

    group('enableLiveUpload', () {
      test('should have default value of false', () {
        expect(FeatureFlags.enableLiveUpload, isFalse);
      });

      test('should be settable to true', () {
        FeatureFlags.enableLiveUpload = true;
        expect(FeatureFlags.enableLiveUpload, isTrue);
      });

      test('should be settable to false', () {
        FeatureFlags.enableLiveUpload = true;
        FeatureFlags.enableLiveUpload = false;
        expect(FeatureFlags.enableLiveUpload, isFalse);
      });

      test('should maintain state when changed', () {
        // Initially false
        expect(FeatureFlags.enableLiveUpload, isFalse);
        
        // Change to true
        FeatureFlags.enableLiveUpload = true;
        expect(FeatureFlags.enableLiveUpload, isTrue);
        
        // Should still be true
        expect(FeatureFlags.enableLiveUpload, isTrue);
      });
    });

    group('feature flag independence', () {
      test('should not affect other feature flags when changed', () {
        // Store initial values
        final initialHideSurfaceAnomalySensor = FeatureFlags.hideSurfaceAnomalySensor;
        final initialShowPrivacyPolicyScreen = FeatureFlags.showPrivacyPolicyScreen;
        
        // Change enableLiveUpload
        FeatureFlags.enableLiveUpload = true;
        
        // Other flags should remain unchanged
        expect(FeatureFlags.hideSurfaceAnomalySensor, equals(initialHideSurfaceAnomalySensor));
        expect(FeatureFlags.showPrivacyPolicyScreen, equals(initialShowPrivacyPolicyScreen));
      });
    });
  });
}