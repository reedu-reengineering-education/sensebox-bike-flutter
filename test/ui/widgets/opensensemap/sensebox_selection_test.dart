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
import 'package:sensebox_bike/ui/widgets/common/loader.dart';

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
    });

    testWidgets('shows error message when configuration loading fails',
        (WidgetTester tester) async {
      when(() => mockConfigurationBloc.boxConfigurationsError)
          .thenReturn('Configuration error');

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

    testWidgets('shows loader when configurations are loading',
        (WidgetTester tester) async {
      when(() => mockConfigurationBloc.isLoadingBoxConfigurations)
          .thenReturn(true);

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

      expect(find.byType(Loader), findsOneWidget);
    });

    testWidgets('shows empty state when no boxes available',
        (WidgetTester tester) async {
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

  });
}

