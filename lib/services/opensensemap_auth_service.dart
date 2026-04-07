import 'package:sensebox_bike/services/opensensemap_service.dart';

class OpenSenseMapAuthService {
  OpenSenseMapAuthService({
    required OpenSenseMapService service,
  }) : _service = service;

  final OpenSenseMapService _service;

  Future<bool> authenticateFromStoredTokens() async {
    final isTokenValid = await _service.isCurrentAccessTokenValid();
    if (isTokenValid) {
      return true;
    }

    final refreshToken = await _service.getRefreshTokenFromPreferences();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    if (_service.isPermanentlyDisabled) {
      return false;
    }

    final tokens = await _service.refreshToken();
    if (tokens == null) {
      return false;
    }

    if (_service.isPermanentlyDisabled) {
      _service.resetPermanentDisable();
    }
    return true;
  }
}
