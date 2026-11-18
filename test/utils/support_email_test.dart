import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/utils/support_email.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));
  final german = lookupAppLocalizations(const Locale('de'));

  SenseBox box() => SenseBox()
    ..name = 'Maria bike'
    ..grouptag = ['bike', 'classic', 'muenster-2026'];

  test('addresses the support inbox with a support subject', () {
    final uri = buildSupportEmailUri(english, installationId: 'abcd-1234');

    expect(uri.scheme, 'mailto');
    expect(uri.path, contactEmail);
    expect(uri.queryParameters['subject'], english.supportEmailSubject);
    expect(uri.toString(), isNot(contains('+')));
  });

  test('lists everything known about the installation below the prompt', () {
    final uri = buildSupportEmailUri(
      english,
      installationId: 'abcd-1234',
      appVersion: '2.1.0 (42)',
      storageDetails: 'App data: 5 MB (database: 3 MB)',
      senseBox: box(),
    );
    final body = uri.queryParameters['body']!;

    expect(body, startsWith(english.supportEmailIntro));
    expect(body, contains('Installation ID: abcd-1234'));
    expect(body, contains('Version: 2.1.0 (42)'));
    expect(body, contains('App data: 5 MB (database: 3 MB)'));
    expect(body, contains('senseBox: Maria bike'));
    expect(body, contains('Campaign and tags: classic, muenster-2026'));
  });

  test('leaves out what is unknown', () {
    final body = buildSupportEmailUri(english, installationId: 'abcd-1234')
        .queryParameters['body']!;

    expect(body, contains('Installation ID: abcd-1234'));
    expect(body, isNot(contains('senseBox:')));
    expect(body, isNot(contains('Campaign')));
  });

  test('uses the language of the app', () {
    final uri = buildSupportEmailUri(
      german,
      installationId: 'abcd-1234',
      senseBox: box(),
    );
    final body = uri.queryParameters['body']!;

    expect(uri.queryParameters['subject'], 'Support-Anfrage: senseBox:bike App');
    expect(body, startsWith(german.supportEmailIntro));
    expect(body, contains('Installations-ID: abcd-1234'));
    expect(body, contains('Kampagne und Tags: classic, muenster-2026'));
  });
}
