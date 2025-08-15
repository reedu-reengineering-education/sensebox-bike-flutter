import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/ui/widgets/common/no_tracks_message.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

void main() {
  group('NoTracksMessage', () {
    testWidgets('displays correct message and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NoTracksMessage(),
          ),
        ),
      );

      // Check if the route icon is displayed
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);

      // Check if the no tracks message is displayed
      expect(find.text('No tracks available'), findsOneWidget);
    });

    testWidgets('is properly centered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NoTracksMessage(),
          ),
        ),
      );

      expect(find.byType(NoTracksMessage), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.text('No tracks available'), findsOneWidget);
    });
  });
}