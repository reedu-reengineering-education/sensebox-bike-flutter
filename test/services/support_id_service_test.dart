import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/services/support_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportIdFormat = RegExp(r'^[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}$');

  setUp(SupportIdService.resetCacheForTesting);

  test('generates a short, readable hex ID', () {
    expect(SupportIdService.generateSupportId(), matches(supportIdFormat));
    expect(
      SupportIdService.generateSupportId(Random(1)),
      SupportIdService.generateSupportId(Random(1)),
    );
  });

  test('creates an ID once and persists it', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await SupportIdService.getOrCreate();
    SupportIdService.resetCacheForTesting();
    final second = await SupportIdService.getOrCreate();

    expect(first, matches(supportIdFormat));
    expect(second, first);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SharedPreferencesKeys.supportId), first);
  });

  test('reuses an ID that is already stored', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesKeys.supportId: 'abcd-1234-ef56',
    });

    expect(await SupportIdService.getOrCreate(), 'abcd-1234-ef56');
  });
}
