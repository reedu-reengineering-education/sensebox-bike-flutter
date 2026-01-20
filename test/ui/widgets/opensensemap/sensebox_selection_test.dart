import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';
import 'package:sensebox_bike/ui/widgets/common/error_message.dart';

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
    registerFallbackValue(SenseBox(
      sId: 'test',
      name: 'Test Box',
      exposure: 'outdoor',
      sensors: [],
    ));
  });

  group('SenseBoxSelectionWidget', () {
    late MockConfigurationBloc mockConfigurationBloc;
    late TestableMockOpenSenseMapBloc mockOpenSenseMapBloc;
    final mockBoxConfiguration = BoxConfiguration(
      id: 'classic',
      displayName: '2022',
      defaultGrouptag: 'classic',
      sensors: [],
    );

    setUp(() {
      mockConfigurationBloc = MockConfigurationBloc();
      mockOpenSenseMapBloc = TestableMockOpenSenseMapBloc();
      
      when(() => mockConfigurationBloc.boxConfigurations)
          .thenReturn([mockBoxConfiguration]);
      when(() => mockConfigurationBloc.campaigns).thenReturn(null);
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(false);
      when(() => mockConfigurationBloc.isLoadingCampaigns).thenReturn(false);
      when(() => mockConfigurationBloc.boxConfigurationsError).thenReturn(null);
      when(() => mockConfigurationBloc.campaignsError).thenReturn(null);
      when(() => mockConfigurationBloc.isSenseBoxBikeCompatible(any()))
          .thenReturn(true);
    });

    testWidgets('shows loader when boxes are loading',
        (WidgetTester tester) async {
      final completer = Completer<List<dynamic>>();
      mockOpenSenseMapBloc.setFetchSenseBoxesFuture(completer.future);

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<OpenSenseMapBloc>.value(
                    value: mockOpenSenseMapBloc),
                Provider<ConfigurationBloc>.value(
                    value: mockConfigurationBloc),
              ],
              child: SenseBoxSelectionWidget(
                configurationBloc: mockConfigurationBloc,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error message when boxes fetch fails',
        (WidgetTester tester) async {
      mockOpenSenseMapBloc.setFetchSenseBoxesError(Exception('Failed to fetch boxes'));

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<OpenSenseMapBloc>.value(
                    value: mockOpenSenseMapBloc),
                Provider<ConfigurationBloc>.value(
                    value: mockConfigurationBloc),
              ],
              child: SenseBoxSelectionWidget(
                configurationBloc: mockConfigurationBloc,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorMessage), findsOneWidget);
    });

    testWidgets('shows empty state when no boxes available',
        (WidgetTester tester) async {
      mockOpenSenseMapBloc.isAuthenticated = true;
      mockOpenSenseMapBloc.setFetchSenseBoxesResult([]);

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<OpenSenseMapBloc>.value(
                    value: mockOpenSenseMapBloc),
                Provider<ConfigurationBloc>.value(
                    value: mockConfigurationBloc),
              ],
              child: SenseBoxSelectionWidget(
                configurationBloc: mockConfigurationBloc,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.directions_bike), findsOneWidget);
    });

    testWidgets('shows list when boxes are available',
        (WidgetTester tester) async {
      final mockBoxes = [
        {
          '_id': 'box1',
          'name': 'Test Box 1',
          'exposure': 'outdoor',
          'grouptag': <String>[],
          'sensors': [],
        },
        {
          '_id': 'box2',
          'name': 'Test Box 2',
          'exposure': 'outdoor',
          'grouptag': <String>[],
          'sensors': [],
        },
      ];
      
      mockOpenSenseMapBloc.setSenseBoxes(mockBoxes);
      mockOpenSenseMapBloc.setFetchSenseBoxesResult(mockBoxes);

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: MultiProvider(
              providers: [
                ChangeNotifierProvider<OpenSenseMapBloc>.value(
                    value: mockOpenSenseMapBloc),
                Provider<ConfigurationBloc>.value(
                    value: mockConfigurationBloc),
              ],
              child: SenseBoxSelectionWidget(
                configurationBloc: mockConfigurationBloc,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Box 1'), findsOneWidget);
      expect(find.text('Test Box 2'), findsOneWidget);
    });

  });
}


