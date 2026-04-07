import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/services/opensensemap_auth_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

class MockOpenSenseMapService extends Mock implements OpenSenseMapService {}

void main() {
  group('OpenSenseMapAuthService', () {
    late MockOpenSenseMapService mockService;
    late OpenSenseMapAuthService authService;

    setUp(() {
      mockService = MockOpenSenseMapService();
      authService = OpenSenseMapAuthService(service: mockService);
    });

    test('returns true when current access token is valid', () async {
      when(() => mockService.isCurrentAccessTokenValid())
          .thenAnswer((_) async => true);

      final result = await authService.authenticateFromStoredTokens();

      expect(result, isTrue);
      verifyNever(() => mockService.getRefreshTokenFromPreferences());
      verifyNever(() => mockService.refreshToken());
    });

    test('returns false when no refresh token exists', () async {
      when(() => mockService.isCurrentAccessTokenValid())
          .thenAnswer((_) async => false);
      when(() => mockService.getRefreshTokenFromPreferences())
          .thenAnswer((_) async => null);

      final result = await authService.authenticateFromStoredTokens();

      expect(result, isFalse);
      verifyNever(() => mockService.refreshToken());
    });

    test('returns false when service is permanently disabled', () async {
      when(() => mockService.isCurrentAccessTokenValid())
          .thenAnswer((_) async => false);
      when(() => mockService.getRefreshTokenFromPreferences())
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockService.isPermanentlyDisabled).thenReturn(true);

      final result = await authService.authenticateFromStoredTokens();

      expect(result, isFalse);
      verifyNever(() => mockService.refreshToken());
    });

    test('returns true and resets permanent disable after successful refresh',
        () async {
      var disabledCallCount = 0;
      when(() => mockService.isCurrentAccessTokenValid())
          .thenAnswer((_) async => false);
      when(() => mockService.getRefreshTokenFromPreferences())
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockService.isPermanentlyDisabled).thenAnswer((_) {
        disabledCallCount += 1;
        return disabledCallCount > 1;
      });
      when(() => mockService.refreshToken()).thenAnswer(
        (_) async => {
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        },
      );
      when(() => mockService.resetPermanentDisable()).thenReturn(null);

      final result = await authService.authenticateFromStoredTokens();

      expect(result, isTrue);
      verify(() => mockService.refreshToken()).called(1);
      verify(() => mockService.resetPermanentDisable()).called(1);
    });

    test('returns false when refresh fails', () async {
      when(() => mockService.isCurrentAccessTokenValid())
          .thenAnswer((_) async => false);
      when(() => mockService.getRefreshTokenFromPreferences())
          .thenAnswer((_) async => 'refresh-token');
      when(() => mockService.isPermanentlyDisabled).thenReturn(false);
      when(() => mockService.refreshToken()).thenAnswer((_) async => null);

      final result = await authService.authenticateFromStoredTokens();

      expect(result, isFalse);
      verify(() => mockService.refreshToken()).called(1);
      verifyNever(() => mockService.resetPermanentDisable());
    });
  });
}
