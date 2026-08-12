import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sensebox_bike/utils/url_launch_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class _MockLaunchUrl extends Mock {
  Future<bool> call(Uri url, {LaunchMode mode = LaunchMode.platformDefault});
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(LaunchMode.externalApplication);
  });

  test('launches external URL', () async {
    final mockLaunch = _MockLaunchUrl();
    when(() => mockLaunch(any(), mode: any(named: 'mode')))
        .thenAnswer((_) async => true);

    await launchExternalUrl(
      'https://example.com',
      launchUrlFunction: (url, {LaunchMode mode = LaunchMode.platformDefault}) =>
          mockLaunch(url, mode: mode),
    );

    verify(
      () => mockLaunch(
        Uri.parse('https://example.com'),
        mode: LaunchMode.externalApplication,
      ),
    ).called(1);
  });

  test('swallows launch errors', () async {
    final mockLaunch = _MockLaunchUrl();
    when(() => mockLaunch(any(), mode: any(named: 'mode')))
        .thenThrow(Exception('launch failed'));

    await expectLater(
      launchExternalUrl(
        'https://example.com',
        launchUrlFunction:
            (url, {LaunchMode mode = LaunchMode.platformDefault}) =>
                mockLaunch(url, mode: mode),
      ),
      completes,
    );
  });
}
