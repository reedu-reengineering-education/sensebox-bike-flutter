import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';

import '../../../mocks.dart';
import '../../../test_helpers.dart';

void main() {
  group('CreateBikeBoxModal - Custom Grouptag', () {
    late MockTagService mockTagService;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;

    setUpAll(() {
      registerFallbackValue(SenseBoxBikeModel.atrai);
    });

    setUp(() {
      mockTagService = MockTagService();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      when(() => mockTagService.loadTags()).thenAnswer((_) async => []);
    });

    testWidgets('shows ExpansionTile for custom grouptag',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: CreateBikeBoxModal(
            tagService: mockTagService,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Add custom group tag'), findsOneWidget);
    });

    testWidgets('accepts custom grouptag input and splits tags',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(body: CreateBikeBoxModal(tagService: mockTagService)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add custom group tag'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'foo, bar ,baz');
      expect(find.text('foo, bar ,baz'), findsOneWidget);
    });

    testWidgets(
        'splits the custom grouptag input into individual tags and passes them to the createSenseBoxBike method',
        (WidgetTester tester) async {
      final mockGeolocationBloc = MockGeolocationBloc();
      when(() => mockGeolocationBloc.getCurrentLocation())
          .thenAnswer((_) async => Position(
                latitude: 50.0,
                longitude: 8.0,
                timestamp: DateTime.now(),
                accuracy: 1.0,
                altitude: 0.0,
                heading: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
                altitudeAccuracy: 0.0,
                headingAccuracy: 0.0,
              ));

      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<OpenSenseMapBloc>.value(
                  value: mockOpenSenseMapBloc),
              ChangeNotifierProvider<GeolocationBloc>.value(
                  value: mockGeolocationBloc),
            ],
            child: CreateBikeBoxModal(
              tagService: mockTagService,
            ),
          ),
        ),
      ));
      // enter text in the name field
      await tester.enterText(find.byType(TextFormField).first, 'My Bike');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add custom group tag'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'foo, bar ,baz');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      verify(() => mockOpenSenseMapBloc.createSenseBoxBike(
          any(), any(), any(), any(), any(), ['foo', 'bar', 'baz'])).called(1);
    });
  });
  group('CreateBikeBoxModal - Location Selection', () {
    late MockTagService mockTagService;
    final mockTags = [
      {'label': 'Wiesbaden', 'value': 'wiesbaden'},
      {'label': 'Münster', 'value': 'muenster'},
      {'label': 'Arnsberg', 'value': 'arnsberg'},
    ];

    setUp(() {
      mockTagService = MockTagService();
      when(() => mockTagService.loadTags()).thenAnswer((_) async => mockTags);
    });

    testWidgets(
        'should populate dropdown with tags and select the first tag by default',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
            body: CreateBikeBoxModal(
          tagService: mockTagService,
        )),
      ));
      await tester.pumpAndSettle();

      // Expand the dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget); // Ensure the dropdown exists
      await tester.tap(dropdownFinder); // Tap the dropdown to expand it
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Wiesbaden'), findsOneWidget);
      expect(find.text('Münster'), findsOneWidget);
      expect(find.text('Arnsberg'), findsOneWidget);
    });

    testWidgets('should update selectedTag when a new tag is selected',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
            body: CreateBikeBoxModal(
          tagService: mockTagService,
        )),
      ));
      await tester.pumpAndSettle();

      // Expand the dropdown
      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      expect(dropdownFinder, findsOneWidget); // Ensure the dropdown exists
      await tester.tap(dropdownFinder); // Tap the dropdown to expand it
      await tester.pumpAndSettle();
      await tester.tap(find.text('Münster').last); // Select 'muenster'
      await tester.pumpAndSettle();

      // Assert
      // Verify the selected tag by checking the displayed text
      expect(find.text('Münster'), findsOneWidget); // Verify the selected tag
    });

    testWidgets(
        'should display data in german, when corresponding locale is selected',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('de'),
        child: Scaffold(
            body: CreateBikeBoxModal(
          tagService: mockTagService,
        )),
      ));
      await tester.pumpAndSettle();
      // Verify the selected tag by checking the displayed text
      // Find the DropdownMenuItem with the translated text
      final dropdownItemFinder =
          find.widgetWithText(DropdownMenuItem<String>, 'Kampagne auswählen');
      expect(dropdownItemFinder,
          findsOneWidget); // Verify the translated dropdown item exists
    });

    testWidgets(
        'should display data in portugese, when corresponding locale is selected',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('pt'),
        child: Scaffold(
            body: CreateBikeBoxModal(
          tagService: mockTagService,
        )),
      ));
      await tester.pumpAndSettle();
      // Verify the selected tag by checking the displayed text
      final dropdownItemFinder =
          find.widgetWithText(DropdownMenuItem<String>, 'Selecionar campanha');
      expect(dropdownItemFinder,
          findsOneWidget); // Verify the translated dropdown item exists
    });
  });
}
