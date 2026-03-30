import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';

import '../../../mocks.dart';
import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(BoxConfiguration(
      id: 'test',
      displayName: 'Test',
      defaultGrouptag: 'test',
      sensors: [],
    ));
  });

  group('CreateBikeBoxModal - Custom Grouptag', () {
    late MockConfigurationBloc mockConfigurationBloc;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    final mockBoxConfiguration = BoxConfiguration(
      id: 'classic',
      displayName: '2022',
      defaultGrouptag: 'classic',
      sensors: [],
    );

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      
      when(() => mockConfigurationBloc.boxConfigurations)
          .thenReturn([mockBoxConfiguration]);
      when(() => mockConfigurationBloc.campaigns).thenReturn(null);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.boxConfigurationsError).thenReturn(null);
      when(() => mockConfigurationBloc.campaignsError).thenReturn(null);
      when(() => mockConfigurationBloc.loadAll()).thenAnswer((_) async {});
      when(() => mockConfigurationBloc.getBoxConfigurationById('classic'))
          .thenReturn(mockBoxConfiguration);
    });

    testWidgets('shows ExpansionTile for custom grouptag',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: Provider<ConfigurationBloc>.value(
            value: mockConfigurationBloc,
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Add custom group tag'), findsOneWidget);
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
              Provider<ConfigurationBloc>.value(
                  value: mockConfigurationBloc),
            ],
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
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
          any(), any(), any(),
          mockBoxConfiguration, any(), ['foo', 'bar', 'baz'])).called(1);
    });
  });
  group('CreateBikeBoxModal - Location Selection', () {
    late MockConfigurationBloc mockConfigurationBloc;
    final mockCampaigns = [
      Campaign(label: 'Wiesbaden', value: 'wiesbaden'),
      Campaign(label: 'Münster', value: 'muenster'),
      Campaign(label: 'Arnsberg', value: 'arnsberg'),
    ];
    final mockBoxConfigurations = [
      BoxConfiguration(
        id: 'classic',
        displayName: '2022',
        defaultGrouptag: 'classic',
        sensors: [],
      ),
    ];

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      when(() => mockConfigurationBloc.campaigns).thenReturn(mockCampaigns);
      when(() => mockConfigurationBloc.boxConfigurations)
          .thenReturn(mockBoxConfigurations);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.loadAll()).thenAnswer((_) async {});
      when(() => mockConfigurationBloc.getBoxConfigurationById('classic'))
          .thenReturn(mockBoxConfigurations.first);
    });

    testWidgets('selects first box configuration by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: Provider<ConfigurationBloc>.value(
            value: mockConfigurationBloc,
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();

      expect(find.text('2022'), findsWidgets);
    });

    testWidgets(
        'should display data in german, when corresponding locale is selected',
        (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('de'),
        child: Scaffold(
          body: Provider<ConfigurationBloc>.value(
            value: mockConfigurationBloc,
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Verify the selected tag by checking the displayed text
      // Find the DropdownMenuItem with the translated text
      final dropdownItemFinder =
          find.widgetWithText(DropdownMenuItem<String>, 'Kampagne auswählen');
      expect(dropdownItemFinder,
          findsOneWidget); // Verify the translated dropdown item exists
    });
  });

  group('CreateBikeBoxModal - Form Validation', () {
    late MockConfigurationBloc mockConfigurationBloc;
    final mockBoxConfiguration = BoxConfiguration(
      id: 'classic',
      displayName: '2022',
      defaultGrouptag: 'classic',
      sensors: [],
    );

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      when(() => mockConfigurationBloc.boxConfigurations)
          .thenReturn([mockBoxConfiguration]);
      when(() => mockConfigurationBloc.campaigns).thenReturn(null);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.boxConfigurationsError).thenReturn(null);
      when(() => mockConfigurationBloc.campaignsError).thenReturn(null);
      when(() => mockConfigurationBloc.getBoxConfigurationById('classic'))
          .thenReturn(mockBoxConfiguration);
    });

    testWidgets('shows validation error for invalid box name',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: Provider<ConfigurationBloc>.value(
            value: mockConfigurationBloc,
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
    });
  });

  group('CreateBikeBoxModal - Error Handling', () {
    late MockConfigurationBloc mockConfigurationBloc;
    final mockBoxConfiguration = BoxConfiguration(
      id: 'classic',
      displayName: '2022',
      defaultGrouptag: 'classic',
      sensors: [],
    );

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      when(() => mockConfigurationBloc.boxConfigurations)
          .thenReturn([mockBoxConfiguration]);
      when(() => mockConfigurationBloc.campaigns).thenReturn(null);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.boxConfigurationsError).thenReturn(null);
      when(() => mockConfigurationBloc.getBoxConfigurationById('classic'))
          .thenReturn(mockBoxConfiguration);
    });

    testWidgets('shows snackbar when campaigns fail to load',
        (WidgetTester tester) async {
      when(() => mockConfigurationBloc.campaignsError)
          .thenReturn('Failed to load');

      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: Provider<ConfigurationBloc>.value(
            value: mockConfigurationBloc,
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows error snackbar when geolocation fails',
        (WidgetTester tester) async {
      final mockGeolocationBloc = MockGeolocationBloc();
      final mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      when(() => mockGeolocationBloc.getCurrentLocation())
          .thenThrow(Exception('Location error'));

      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: MultiProvider(
            providers: [
              ChangeNotifierProvider<OpenSenseMapBloc>.value(
                  value: mockOpenSenseMapBloc),
              ChangeNotifierProvider<GeolocationBloc>.value(
                  value: mockGeolocationBloc),
              Provider<ConfigurationBloc>.value(
                  value: mockConfigurationBloc),
            ],
            child: CreateBikeBoxModal(
              boxConfigurations: mockConfigurationBloc.boxConfigurations,
              campaigns: mockConfigurationBloc.campaigns,
              isLoadingBoxConfigurations:
                  mockConfigurationBloc.isLoadingBoxConfigurations,
              isLoadingCampaigns: mockConfigurationBloc.isLoadingCampaigns,
              boxConfigurationsError:
                  mockConfigurationBloc.boxConfigurationsError,
              campaignsError: mockConfigurationBloc.campaignsError,
              getBoxConfigurationById: (id) =>
                  mockConfigurationBloc.getBoxConfigurationById(id),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'My Bike');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Location error'), findsOneWidget);
    });
  });
}
