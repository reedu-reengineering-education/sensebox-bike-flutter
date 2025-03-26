import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:provider/provider.dart';
import '../mocks.dart';
import '../test_helpers.dart';

// Alternative Isar mocking solutions: 
// https://github.com/isar/isar/issues/1459
// https://github.com/isar/isar/issues/294
// https://github.com/isar/isar/issues/1147 (with Mockito)
void main() {
  late MockIsarService mockIsarService;

  setUpAll(() async {
    disableProviderDebugChecks();
    await initializeTestDependencies();
  });

  setUp(() {
    mockIsarService = MockIsarService();
  });

  Widget buildTestWidget(Locale locale) {
    return createLocalizedTestApp(
      locale: locale,
      child: Provider<IsarService>(
        create: (_) => mockIsarService, // Provide the mock
        child: const TracksScreen(),
      ),
    );
  }
  group('TracksScreen Widget', () {
    testWidgets("is translated in English", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('en')));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in German", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('de')));
      expect(find.text('Tracks'), findsOneWidget);
    });

    testWidgets("is translated in Portugese", (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('pt')));
      expect(find.text('Trajetos'), findsOneWidget);
    });
  });
}
