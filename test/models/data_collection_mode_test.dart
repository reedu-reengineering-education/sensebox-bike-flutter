import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';

void main() {
  group('DataCollectionMode', () {
    test('parses known values and defaults', () {
      expect(DataCollectionMode.fromJson(null), DataCollectionMode.gpsDriven);
      expect(
        DataCollectionMode.fromJson('gpsDriven'),
        DataCollectionMode.gpsDriven,
      );
      expect(
        DataCollectionMode.fromJson('postRide'),
        DataCollectionMode.gpsDriven,
      );
      expect(
        DataCollectionMode.fromJson('periodic'),
        DataCollectionMode.periodic,
      );
      expect(DataCollectionMode.fromJson('onTap'), DataCollectionMode.onTap);
    });

    test('behavior helpers', () {
      expect(DataCollectionMode.gpsDriven.usesGpsStreamPersistence, isTrue);
      expect(DataCollectionMode.gpsDriven.aggregatesSensorValues, isTrue);
      expect(DataCollectionMode.periodic.usesPeriodicTimer, isTrue);
      expect(DataCollectionMode.onTap.showsManualSampleButton, isTrue);
      expect(DataCollectionMode.onTap.aggregatesSensorValues, isFalse);
    });

    test('parseCollectionIntervalSeconds validates', () {
      expect(parseCollectionIntervalSeconds(null), defaultCollectionIntervalSeconds);
      expect(parseCollectionIntervalSeconds(30), 30);
      expect(
        () => parseCollectionIntervalSeconds(2),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseCollectionIntervalSeconds('60'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
