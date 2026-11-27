import 'dart:convert';
import 'dart:io';

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
import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
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
  List<SensorCatalogEntry>? sensorCatalog,
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
      sensorCatalog: sensorCatalog,
    ),
  );
}

/// The model card showing [title] when it is the selected one.
Finder _selectedModelCard(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.selected == true),
    );

List<SensorCatalogEntry> _repoSensorCatalog() {
  return (jsonDecode(File('data/sensors.json').readAsStringSync()) as List)
      .map((e) => SensorCatalogEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

Position _testPosition() => Position(
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
    );

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

    testWidgets('shows optional fields directly and no recording settings',
        (WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Campaign (optional)'), findsOneWidget);
      expect(find.text('Group tags (optional)'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Advanced data recording'), findsNothing);
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
      await tester.enterText(find.byType(TextFormField).last, 'foo, bar ,baz');
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      verify(() => mockOpenSenseMapBloc.createSenseBoxBike(any(), any(), any(),
          mockBoxConfiguration, any(), ['foo', 'bar', 'baz'])).called(1);
      // Recording preferences are app settings, not part of a box.
      verifyNever(
        () => mockSettingsBloc.setCollectionPreferences(
          mode: any(named: 'mode'),
          intervalSeconds: any(named: 'intervalSeconds'),
        ),
      );
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

      expect(_selectedModelCard('2022'), findsOneWidget);
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
          find.widgetWithText(DropdownMenuItem<String>, 'Keine Kampagne');
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
      await tester
          .ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
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
      await tester
          .ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Location error'), findsOneWidget);
    });
  });

  group('CreateBikeBoxModal - Custom sensor selection', () {
    late MockConfigurationBloc mockConfigurationBloc;
    late MockOpenSenseMapBloc mockOpenSenseMapBloc;
    late MockGeolocationBloc mockGeolocationBloc;
    final mockBoxConfiguration = BoxConfiguration(
      id: 'classic',
      displayName: '2022',
      defaultGrouptag: 'classic',
      sensors: [],
    );

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      mockOpenSenseMapBloc = MockOpenSenseMapBloc();
      mockGeolocationBloc = MockGeolocationBloc();
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
      when(() => mockOpenSenseMapBloc.createSenseBoxBike(
          any(), any(), any(), any(), any(), any())).thenAnswer((_) async {});
      when(() => mockGeolocationBloc.getCurrentLocation())
          .thenAnswer((_) async => _testPosition());
    });

    Future<void> pumpModal(WidgetTester tester,
        {List<SensorCatalogEntry>? sensorCatalog}) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: _pumpCreateModal(
            configurationBloc: mockConfigurationBloc,
            openSenseMapBloc: mockOpenSenseMapBloc,
            geolocationBloc: mockGeolocationBloc,
            sensorCatalog: sensorCatalog,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> selectCustomModel(WidgetTester tester) async {
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
    }

    Future<void> tapCreate(WidgetTester tester) async {
      await tester
          .ensureVisible(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ButtonWithLoader, 'Create'));
      await tester.pumpAndSettle();
    }

    testWidgets('hides the custom option without a sensor catalog',
        (WidgetTester tester) async {
      await pumpModal(tester);

      expect(find.text('Custom'), findsNothing);
    });

    testWidgets('shows sensor chips only when custom is selected',
        (WidgetTester tester) async {
      await pumpModal(tester, sensorCatalog: _repoSensorCatalog());

      expect(find.byType(FilterChip), findsNothing);

      await selectCustomModel(tester);

      expect(find.byType(FilterChip), findsNWidgets(10));
      expect(find.widgetWithText(FilterChip, 'Temperature'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Finedust'), findsOneWidget);
    });

    testWidgets('requires at least one sensor for a custom box',
        (WidgetTester tester) async {
      await pumpModal(tester, sensorCatalog: _repoSensorCatalog());
      await tester.enterText(find.byType(TextFormField).first, 'My Box');
      await selectCustomModel(tester);

      await tapCreate(tester);

      expect(find.text('Please select at least one sensor'), findsOneWidget);
      verifyNever(() => mockOpenSenseMapBloc.createSenseBoxBike(
          any(), any(), any(), any(), any(), any()));
    });

    testWidgets('creates a box with the selected sensors',
        (WidgetTester tester) async {
      await pumpModal(tester, sensorCatalog: _repoSensorCatalog());
      await tester.enterText(find.byType(TextFormField).first, 'My Box');
      await selectCustomModel(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Temperature'));
      await tester.tap(find.widgetWithText(FilterChip, 'Finedust'));
      await tester.pumpAndSettle();
      await tapCreate(tester);

      final captured = verify(() => mockOpenSenseMapBloc.createSenseBoxBike(
            'My Box',
            any(),
            any(),
            captureAny(),
            any(),
            any(),
          )).captured;
      final config = captured.single as BoxConfiguration;
      expect(config.id, BoxConfiguration.customId);
      expect(config.sensors.map((s) => s.title), [
        'Temperature',
        'Finedust PM1',
        'Finedust PM2.5',
        'Finedust PM4',
        'Finedust PM10',
      ]);
    });
  });

  group('CreateBikeBoxModal - Featured models', () {
    late MockConfigurationBloc mockConfigurationBloc;
    BoxConfiguration config(String id, String name, {bool featured = false}) =>
        BoxConfiguration(
          id: id,
          displayName: name,
          defaultGrouptag: id,
          sensors: [],
          featured: featured,
        );

    void stubConfigs(List<BoxConfiguration> configs) {
      when(() => mockConfigurationBloc.boxConfigurations).thenReturn(configs);
    }

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      when(() => mockConfigurationBloc.campaigns).thenReturn(null);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.boxConfigurationsError).thenReturn(null);
      when(() => mockConfigurationBloc.campaignsError).thenReturn(null);
    });

    Future<void> pumpModal(WidgetTester tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        locale: Locale('en'),
        child: Scaffold(
          body: _pumpCreateModal(configurationBloc: mockConfigurationBloc),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('selects the featured model and hides the others',
        (WidgetTester tester) async {
      stubConfigs([
        config('classic', '2022'),
        config('atrai', 'senseBox:bike', featured: true),
      ]);
      await pumpModal(tester);

      expect(_selectedModelCard('senseBox:bike'), findsOneWidget);
      expect(find.text('2022'), findsNothing);

      await tester.tap(find.text('More models'));
      await tester.pumpAndSettle();

      expect(find.text('2022'), findsOneWidget);
    });

    testWidgets('shows every model when none is featured',
        (WidgetTester tester) async {
      stubConfigs([config('classic', '2022'), config('atrai', '2025')]);
      await pumpModal(tester);

      expect(find.text('2022'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('More models'), findsNothing);
    });
  });
}
