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

    // Text is present
    expect(find.text(testText), findsOneWidget);

    // Icon uses the default blue color
    final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
    expect(icon.color, Colors.blue);

    // Container has the expected background tint
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.blue.withOpacity(0.1));
  });
}
