import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/utils/date_utils.dart';

void main() {
  group('toUtc', () {
    test('returns same DateTime when already UTC', () {
      final utcTime = DateTime.utc(2024, 1, 1, 12, 0, 0);
      final result = toUtc(utcTime);

      expect(result, equals(utcTime));
      expect(result.isUtc, isTrue);
    });

    test('converts local DateTime to UTC', () {
      final localTime = DateTime(2024, 1, 1, 12, 0, 0);
      expect(localTime.isUtc, isFalse);

      final result = toUtc(localTime);

      expect(result.isUtc, isTrue);
      expect(result, equals(localTime.toUtc()));
    });

    test('handles DateTime with timezone offset', () {
      final localTime = DateTime(2024, 6, 15, 14, 30, 0);
      final result = toUtc(localTime);

      expect(result.isUtc, isTrue);
      expect(result, equals(localTime.toUtc()));
    });

    test('preserves DateTime value when already UTC', () {
      final utcTime = DateTime.utc(2024, 12, 25, 23, 59, 59);
      final result = toUtc(utcTime);

      expect(result.millisecondsSinceEpoch, equals(utcTime.millisecondsSinceEpoch));
      expect(result.isUtc, isTrue);
    });

    test('handles edge case of year boundary', () {
      final localTime = DateTime(2023, 12, 31, 23, 59, 59);
      final result = toUtc(localTime);

      expect(result.isUtc, isTrue);
      expect(result.year, equals(localTime.toUtc().year));
    });
  });
}

