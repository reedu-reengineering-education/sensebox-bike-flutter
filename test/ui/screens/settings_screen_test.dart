import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../test_helpers.dart';

class MockLaunchUrl extends Mock {
  Future<bool> call(Uri url, {LaunchMode mode});
}

void main() {
  late MockLaunchUrl mockLaunchUrl;
  late SettingsBloc mockSettingsBloc;

  setUpAll(() {
    // Register fallback values for Uri and LaunchMode
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(LaunchMode.externalApplication);
  });

  setUp(() {
    mockLaunchUrl = MockLaunchUrl();
    mockSettingsBloc = SettingsBloc();
  });


  testWidgets('launches correct URLs when buttons are tapped',
      (WidgetTester tester) async {
    // Mock the launchUrl function
    when(() => mockLaunchUrl.call(any(), mode: any(named: 'mode')))
        .thenAnswer((_) async => true);

    await tester.pumpWidget(
      createLocalizedTestApp(
      locale: const Locale('en'),
      child: ChangeNotifierProvider<SettingsBloc>.value(
        value: mockSettingsBloc,
        child: SettingsScreen(launchUrlFunction: mockLaunchUrl.call),
      ),
    ));

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse(senseBoxBikePrivacyPolicyUrl),
          mode: any(named: 'mode'),
        )).called(1);

    await tester.tap(find.text('E-mail'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse('mailto:$contactEmail?subject=senseBox:bike%20App'),
          mode: any(named: 'mode'),
        )).called(1);

    await tester.tap(find.text('GitHub issue'));
    await tester.pumpAndSettle();

    verify(() => mockLaunchUrl.call(
          Uri.parse(gitHubNewIssueUrl),
          mode: any(named: 'mode'),
        )).called(1);
  });
}