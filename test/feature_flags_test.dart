import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/feature_flags.dart';

void main() {
  group('FeatureFlags', () {
    setUp(() {
      // Reset all feature flags to their default values before each test
      FeatureFlags.hideSurfaceAnomalySensor = true;
      FeatureFlags.showPrivacyPolicyScreen = false;
    });

    group('feature flag independence', () {
      test('should not affect other feature flags when changed', () {
        // Store initial values
        final initialHideSurfaceAnomalySensor = FeatureFlags.hideSurfaceAnomalySensor;
        final initialShowPrivacyPolicyScreen = FeatureFlags.showPrivacyPolicyScreen;
        
        // Change hideSurfaceAnomalySensor
        FeatureFlags.hideSurfaceAnomalySensor = false;
        
        // Other flags should remain unchanged
        expect(FeatureFlags.showPrivacyPolicyScreen, equals(initialShowPrivacyPolicyScreen));
        
        // Reset back
        FeatureFlags.hideSurfaceAnomalySensor = initialHideSurfaceAnomalySensor;
      });
    });
  });
}