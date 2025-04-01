import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';
import '../mocks.dart';
import '../test_helpers.dart';

void main() {
  late OpenSenseMapBloc mockBloc;

  setUpAll(() {
    disableProviderDebugChecks();
    initializeTestDependencies();
  });

  setUp(() {
    mockBloc = MockOpenSenseMapBloc();
  });

  Widget buildTestWidget(Locale locale) {
    return createLocalizedTestApp(
      locale: locale,
      child: Provider<OpenSenseMapBloc>.value(
        value: mockBloc,
        child: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => showLoginOrSenseBoxSelection(context, mockBloc),
            child: const Text('Show Modal'),
          ),
        ),
      ),
    );
  }

  group('LoginSelectionModal', () {
    testWidgets('is translated in English', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('en')));
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsNWidgets(2));
      expect(find.text('Register with openSenseMap'), findsOneWidget);
    });

    testWidgets('is translated in German', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('de')));
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify German text
      expect(find.text('Anmelden'), findsNWidgets(2));
      expect(find.text('Registrieren bei openSenseMap'), findsOneWidget);
    });

    testWidgets('is translated in Portugese', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const Locale('pt')));
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify German text
      expect(find.text('Entrar'), findsNWidgets(2));
      expect(find.text('Registrar-se no openSenseMap'), findsOneWidget);
    });
  });
}
