import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/installation_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final installationIdFormat = RegExp(r'^[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}$');

  setUp(() => InstallationIdService.setIdForTesting(null));

  test('creates an ID once and persists it', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await InstallationIdService.init();
    final second = await InstallationIdService.init();

    expect(first, matches(installationIdFormat));
    expect(second, first);
    expect(InstallationIdService.id, first);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SharedPreferencesKeys.installationId), first);
  });

  test('reuses an ID that is already stored', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesKeys.installationId: 'abcd-1234-ef56',
    });

    await InstallationIdService.init();

    expect(InstallationIdService.id, 'abcd-1234-ef56');
  });
}
