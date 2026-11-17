import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

import '../../../mocks.dart';
import '../../../test_helpers.dart';

class _FakeOpenSenseMapBloc extends MockOpenSenseMapBloc {
  Future<List<dynamic>>? fetchResult;

  @override
  List<dynamic> senseBoxes = [];

  @override
  Future<List> fetchSenseBoxes({int page = 0}) async {
    senseBoxes = await (fetchResult ?? Future.value([]));
    notifyListeners();
    return senseBoxes;
  }
}

Map<String, dynamic> _boxJson(String id, String name) => {
      '_id': id,
      'name': name,
      'exposure': 'outdoor',
      'grouptag': <String>[],
      'sensors': [],
    };

void main() {
  late MockConfigurationBloc configurationBloc;
  late _FakeOpenSenseMapBloc bloc;

  setUp(() {
    configurationBloc = MockConfigurationBloc();
    bloc = _FakeOpenSenseMapBloc();
    when(() => configurationBloc.boxConfigurations).thenReturn([
      BoxConfiguration(
        id: 'classic',
        displayName: '2022',
        defaultGrouptag: 'classic',
        sensors: [],
      ),
    ]);
    when(() => configurationBloc.isLoadingBoxConfigurations).thenReturn(false);
  });

  Future<void> pumpSelection(WidgetTester tester) => tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: Scaffold(
            body: ChangeNotifierProvider<OpenSenseMapBloc>.value(
              value: bloc,
              child: SenseBoxSelectionWidget(
                configurationBloc: configurationBloc,
              ),
            ),
          ),
        ),
      );

  testWidgets('shows loader while boxes are loading', (tester) async {
    final completer = Completer<List<dynamic>>();
    bloc.fetchResult = completer.future;

    await pumpSelection(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey('sensebox-loading-skeleton-item')),
        findsWidgets);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('shows empty state when no boxes are available', (tester) async {
    bloc.isAuthenticated = true;

    await pumpSelection(tester);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.directions_bike), findsOneWidget);
  });

  testWidgets('lists available boxes', (tester) async {
    bloc.senseBoxes = [
      _boxJson('box1', 'Test Box 1'),
      _boxJson('box2', 'Test Box 2'),
    ];

    await pumpSelection(tester);
    await tester.pumpAndSettle();

    expect(find.text('Test Box 1'), findsOneWidget);
    expect(find.text('Test Box 2'), findsOneWidget);
  });
}
