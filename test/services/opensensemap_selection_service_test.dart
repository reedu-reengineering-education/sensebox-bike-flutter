import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/opensensemap_selection_service.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';

void main() {
  group('OpenSenseMapSelectionService', () {
    late InMemorySelectedSenseBoxStorage storage;
    late OpenSenseMapSelectionService selectionService;

    setUp(() {
      storage = InMemorySelectedSenseBoxStorage();
      selectionService =
          OpenSenseMapSelectionService(selectedSenseBoxStorage: storage);
    });

    SenseBox createSenseBox({
      required String id,
      required String title,
      required String sensorType,
    }) {
      return SenseBox(
        sId: id,
        name: 'Box-$id',
        exposure: 'outdoor',
        grouptag: const [],
        sensors: [
          Sensor(title: title, unit: 'unit', sensorType: sensorType),
        ],
      );
    }

    test('saveSelectedSenseBox stores box JSON and load returns compatible box',
        () async {
      final box = createSenseBox(
        id: 'box-1',
        title: 'Temperature',
        sensorType: 'HDC1080',
      );

      await selectionService.saveSelectedSenseBox(box);
      final loaded = await selectionService.loadSelectedSenseBox(
        isAuthenticated: true,
        isCompatible: (_) => true,
      );

      expect(loaded, isNotNull);
      expect(loaded!.sId, 'box-1');
    });

    test('loadSelectedSenseBox clears and returns null when unauthenticated',
        () async {
      final box = createSenseBox(
        id: 'box-1',
        title: 'Temperature',
        sensorType: 'HDC1080',
      );
      await selectionService.saveSelectedSenseBox(box);

      final loaded = await selectionService.loadSelectedSenseBox(
        isAuthenticated: false,
        isCompatible: (_) => true,
      );

      expect(loaded, isNull);
      expect(await storage.loadSelectedSenseBoxJson(), isNull);
    });

    test('loadSelectedSenseBox clears and returns null when incompatible',
        () async {
      final box = createSenseBox(
        id: 'box-2',
        title: 'Unknown Sensor',
        sensorType: 'UNKNOWN',
      );
      await selectionService.saveSelectedSenseBox(box);

      final loaded = await selectionService.loadSelectedSenseBox(
        isAuthenticated: true,
        isCompatible: (_) => false,
      );

      expect(loaded, isNull);
      expect(await storage.loadSelectedSenseBoxJson(), isNull);
    });

    test('findFirstCompatibleBox returns first compatible match', () {
      final boxes = [
        createSenseBox(id: 'a', title: 'Unknown', sensorType: 'UNKNOWN'),
        createSenseBox(id: 'b', title: 'Temperature', sensorType: 'HDC1080'),
        createSenseBox(id: 'c', title: 'Humidity', sensorType: 'SHT31'),
      ];

      final match = selectionService.findFirstCompatibleBox(
        boxes,
        isCompatible: (box) =>
            box.sensors!.any((s) => s.sensorType == 'HDC1080'),
      );

      expect(match, isNotNull);
      expect(match!.sId, 'b');
    });

    test('clearSelectedSenseBox removes stored box', () async {
      final box = createSenseBox(
        id: 'box-3',
        title: 'Temperature',
        sensorType: 'HDC1080',
      );
      await selectionService.saveSelectedSenseBox(box);
      expect(await storage.loadSelectedSenseBoxJson(), isNotNull);

      await selectionService.clearSelectedSenseBox();

      expect(await storage.loadSelectedSenseBoxJson(), isNull);
    });
  });
}
