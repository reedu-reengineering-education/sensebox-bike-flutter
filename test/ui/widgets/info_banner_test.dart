import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/info_banner.dart';

void main() {
  testWidgets('InfoBanner renders text and icon with blue styling',
      (WidgetTester tester) async {
    const testText = 'Hint message';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoBanner(text: testText),
        ),
      ),
    );

    expect(find.text(testText), findsOneWidget);

    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(icon.color, Colors.blue);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.blue.withOpacity(0.1));
  });

  testWidgets('InfoBanner without URL does not show open icon',
      (WidgetTester tester) async {
    const testText = 'Hint message';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoBanner(text: testText),
        ),
      ),
    );

    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(Ink), findsNothing);
  });

  testWidgets('InfoBanner with URL shows open icon and is tappable',
      (WidgetTester tester) async {
    const testText = 'Click to open';
    const testUrl = 'https://example.com';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoBanner(text: testText, url: testUrl),
        ),
      ),
    );

    expect(find.text(testText), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byType(Ink), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);

    final inkWell = find.byType(InkWell);
    await tester.tap(inkWell);
    await tester.pump();
  });

  testWidgets('InfoBanner with onDismiss shows close icon and triggers callback',
      (WidgetTester tester) async {
    const testText = 'Hint message';
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InfoBanner(
            text: testText,
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}
