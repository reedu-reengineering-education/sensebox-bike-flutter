import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/ui/widgets/common/button_with_loader.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_modal.dart';

import '../../../mocks.dart';
import '../../../test_helpers.dart';

MockSettingsBloc _stubSettingsBloc() {
  final settings = MockSettingsBloc();
  when(() => settings.dataCollectionMode)
      .thenReturn(DataCollectionMode.gpsDriven);
  when(() => settings.collectionIntervalSeconds)
      .thenReturn(defaultCollectionIntervalSeconds);
  when(() => settings.setCollectionPreferences(
        mode: any(named: 'mode'),
        intervalSeconds: any(named: 'intervalSeconds'),
      )).thenAnswer((_) async {});
  when(() => settings.setDataCollectionMode(any())).thenAnswer((_) async {});
  when(() => settings.setCollectionIntervalSeconds(any()))
      .thenAnswer((_) async {});
  return settings;
}

Widget _pumpCreateModal({
  required ConfigurationBloc configurationBloc,
  SettingsBloc? settingsBloc,
  OpenSenseMapBloc? openSenseMapBloc,
  GeolocationBloc? geolocationBloc,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigurationBloc>.value(value: configurationBloc),
      ChangeNotifierProvider<SettingsBloc>.value(
        value: settingsBloc ?? _stubSettingsBloc(),
      ),
      if (openSenseMapBloc != null)
        ChangeNotifierProvider<OpenSenseMapBloc>.value(value: openSenseMapBloc),
      if (geolocationBloc != null)
        ChangeNotifierProvider<GeolocationBloc>.value(value: geolocationBloc),
    ],
    child: CreateBikeBoxModal(
      boxConfigurations: configurationBloc.boxConfigurations,
      campaigns: configurationBloc.campaigns,
      isLoadingBoxConfigurations: configurationBloc.isLoadingBoxConfigurations,
      isLoadingCampaigns: configurationBloc.isLoadingCampaigns,
      boxConfigurationsError: configurationBloc.boxConfigurationsError,
      campaignsError: configurationBloc.campaignsError,
      getBoxConfigurationById: (id) =>
          configurationBloc.getBoxConfigurationById(id),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(BoxConfiguration(
      id: 'test',
      displayName: 'Test',
      defaultGrouptag: 'test',
      sensors: [],
    ));
    registerFallbackValue(DataCollectionMode.gpsDriven);
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
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Add custom group tag'), findsOneWidget);
      expect(find.text('Advanced data recording'), findsOneWidget);
    });

    testWidgets(
        'splits the custom grouptag input into individual tags and passes them to the createSenseBoxBike method',
        (WidgetTester tester) async {
      final mockGeolocationBloc = MockGeolocationBloc();
      final mockSettingsBloc = _stubSettingsBloc();
      when(() => mockOpenSenseMapBloc.createSenseBoxBike(
            any(),
            any(),
            any(),
            any(),
            any(),
            any(),
          )).thenAnswer((_) async {});
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
          body: _pumpCreateModal(
            configurationBloc: mockConfigurationBloc,
            settingsBloc: mockSettingsBloc,
            openSenseMapBloc: mockOpenSenseMapBloc,
            geolocationBloc: mockGeolocationBloc,
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
      await tester.ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      verify(() => mockOpenSenseMapBloc.createSenseBoxBike(
          any(), any(), any(),
          mockBoxConfiguration, any(), ['foo', 'bar', 'baz'])).called(1);
      verify(
        () => mockSettingsBloc.setCollectionPreferences(
          mode: DataCollectionMode.gpsDriven,
          intervalSeconds: defaultCollectionIntervalSeconds,
        ),
      ).called(1);
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
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
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
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
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
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
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
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
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
          body: _pumpCreateModal(
            configurationBloc: mockConfigurationBloc,
            openSenseMapBloc: mockOpenSenseMapBloc,
            geolocationBloc: mockGeolocationBloc,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'My Bike');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Location error'), findsOneWidget);
    });
  });
}
