import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/campaign.dart';

void main() {
  group('Campaign.fromJson', () {
    test('parses valid JSON successfully', () {
      final json = {'label': 'Wiesbaden', 'value': 'wiesbaden'};
      final campaign = Campaign.fromJson(json);
      expect(campaign.label, 'Wiesbaden');
      expect(campaign.value, 'wiesbaden');
    });

    test('throws FormatException when label is missing', () {
      final json = {'value': 'wiesbaden'};
      expect(
        () => Campaign.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "label"'),
        )),
      );
    });

    test('throws FormatException when value is missing', () {
      final json = {'label': 'Wiesbaden'};
      expect(
        () => Campaign.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing required field "value"'),
        )),
      );
    });

    test('throws FormatException when label has wrong type', () {
      final json = {'label': 123, 'value': 'wiesbaden'};
      expect(
        () => Campaign.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a String'),
        )),
      );
    });

    test('throws FormatException when value has wrong type', () {
      final json = {'label': 'Wiesbaden', 'value': 456};
      expect(
        () => Campaign.fromJson(json),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('must be a String'),
        )),
      );
    });
  });
}

