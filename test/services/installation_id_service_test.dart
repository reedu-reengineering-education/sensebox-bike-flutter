import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/support_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportIdFormat = RegExp(r'^[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}$');

  setUp(() => SupportIdService.setIdForTesting(null));

  test('creates an ID once and persists it', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await SupportIdService.init();
    final second = await SupportIdService.init();

    expect(first, matches(supportIdFormat));
    expect(second, first);
    expect(SupportIdService.id, first);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SharedPreferencesKeys.supportId), first);
  });

  test('reuses an ID that is already stored', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesKeys.supportId: 'abcd-1234-ef56',
    });

    await SupportIdService.init();

    expect(SupportIdService.id, 'abcd-1234-ef56');
  });
}
