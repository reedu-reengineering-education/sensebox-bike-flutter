import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_dialog.dart';

import '../../../mocks.dart';
import '../../../test_helpers.dart';

void main() {
  group('CreateBikeBoxDialog - Location Selection', () {
    late MockTagService mockTagService;
    final mockTags = ['other', 'wiesbaden', 'muenster', 'arnsberg'];

    setUp(() {
      mockTagService = MockTagService();
      when(() => mockTagService.loadTags()).thenAnswer((_) async => mockTags);
    });

    testWidgets('should populate dropdown with tags and select the first tag by default', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: Locale('en'),
          child: Scaffold(body: CreateBikeBoxDialog(tagService: mockTagService,)),
      ));
      await tester.pumpAndSettle();
      // Verify that other is selected by default
      expect(find.text('Other'), findsOneWidget);
      // Extpand the dropdown to show the list of locations
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      // Assert
      expect(find.text('Wiesbaden'), findsOneWidget);
      expect(find.text('Münster'), findsOneWidget); 
      expect(find.text('Arnsberg'), findsOneWidget);
    });

    testWidgets('should update selectedTag when a new tag is selected', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: Locale('en'),
          child: Scaffold(body: CreateBikeBoxDialog(tagService: mockTagService,)),
      ));
      await tester.pumpAndSettle();

      // Select a new tag
      await tester.tap(find.text('Other')); // Open the dropdown
      await tester.pumpAndSettle();
      await tester.tap(find.text('Münster').last); // Select 'muenster'
      await tester.pumpAndSettle();

      // Assert
      // Verify the selected tag by checking the displayed text
      expect(find.text('Münster'), findsOneWidget); // Verify the selected tag
    });
  
    testWidgets('should display data in german, when corresponding locale is selected', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: Locale('de'),
          child: Scaffold(body: CreateBikeBoxDialog(tagService: mockTagService,)),
      ));
      await tester.pumpAndSettle();
      // Verify the selected tag by checking the displayed text
      expect(find.text('Anderer'), findsOneWidget); // Verify the selected tag
    });

    testWidgets('should display data in portugese, when corresponding locale is selected', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: Locale('pt'),
          child: Scaffold(body: CreateBikeBoxDialog(tagService: mockTagService,)),
      ));
      await tester.pumpAndSettle();
      // Verify the selected tag by checking the displayed text
      expect(find.text('Outro'), findsOneWidget); // Verify the selected tag
    });
  });
}