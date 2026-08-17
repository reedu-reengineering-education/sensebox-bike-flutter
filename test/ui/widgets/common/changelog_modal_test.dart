import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/changelog_modal.dart';
import 'package:sensebox_bike/utils/changelog_utils.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
    disableProviderDebugChecks();
  });

  group('shouldShowChangelogModal', () {
    test(
        'is true when there is no last-seen version yet (first check ever, '
        'including for users upgrading from before this feature existed)',
        () {
      expect(
        shouldShowChangelogModal(
          lastSeenVersion: null,
          currentVersion: '3.5.0',
        ),
        isTrue,
      );
    });

    test('is false when the version has already been seen', () {
      expect(
        shouldShowChangelogModal(
          lastSeenVersion: '3.5.0',
          currentVersion: '3.5.0',
        ),
        isFalse,
      );
    });

    test('is true after an upgrade', () {
      expect(
        shouldShowChangelogModal(
          lastSeenVersion: '3.4.0',
          currentVersion: '3.5.0',
        ),
        isTrue,
      );
    });
  });

  group('showChangelogModal', () {
    const sections = [
      ChangelogSection(
        category: 'Added',
        items: ['Remember a senseBox and auto-connect to it.'],
      ),
      ChangelogSection(
        category: '',
        items: ['Uncategorized fix.'],
      ),
    ];

    testWidgets('renders the title, sections and closes on tap',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showChangelogModal(
                  context,
                  version: '3.5.0',
                  sections: sections,
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining("What's new in 3.5.0"), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      expect(
        find.text('Remember a senseBox and auto-connect to it.'),
        findsOneWidget,
      );
      expect(find.text('Uncategorized fix.'), findsOneWidget);

      await tapElement(find.text('Close'), tester);
      expect(find.textContaining("What's new in 3.5.0"), findsNothing);
    });
  });
}
