import 'dart:convert';

import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/storage/selected_sensebox_storage.dart';

class OpenSenseMapSelectionService {
  OpenSenseMapSelectionService({
    required SelectedSenseBoxStorage selectedSenseBoxStorage,
  }) : _selectedSenseBoxStorage = selectedSenseBoxStorage;

  final SelectedSenseBoxStorage _selectedSenseBoxStorage;

  Future<void> clearSelectedSenseBox() async {
    await _selectedSenseBoxStorage.clearSelectedSenseBox();
  }

  Future<void> saveSelectedSenseBox(SenseBox? senseBox) async {
    if (senseBox == null) {
      await _selectedSenseBoxStorage.clearSelectedSenseBox();
      return;
    }

    await _selectedSenseBoxStorage
        .saveSelectedSenseBoxJson(jsonEncode(senseBox.toJson()));
  }

  Future<SenseBox?> loadSelectedSenseBox({
    required bool isAuthenticated,
    required bool Function(SenseBox) isCompatible,
  }) async {
    if (!isAuthenticated) {
      await _selectedSenseBoxStorage.clearSelectedSenseBox();
      return null;
    }

    final selectedSenseBoxJson =
        await _selectedSenseBoxStorage.loadSelectedSenseBoxJson();
    if (selectedSenseBoxJson == null) {
      return null;
    }

    final savedSenseBox = SenseBox.fromJson(jsonDecode(selectedSenseBoxJson));
    if (!isCompatible(savedSenseBox)) {
      await _selectedSenseBoxStorage.clearSelectedSenseBox();
      return null;
    }

    return savedSenseBox;
  }

  List<SenseBox> convertJsonToSenseBoxes(List<dynamic> senseBoxesJson) {
    return senseBoxesJson.map((json) => SenseBox.fromJson(json)).toList();
  }

  SenseBox? findFirstCompatibleBox(
    List<SenseBox> senseBoxes, {
    required bool Function(SenseBox) isCompatible,
  }) {
    for (final senseBox in senseBoxes) {
      if (isCompatible(senseBox)) {
        return senseBox;
      }
    }
    return null;
  }
}
