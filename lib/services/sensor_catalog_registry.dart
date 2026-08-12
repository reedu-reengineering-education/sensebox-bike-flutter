import 'package:sensebox_bike/models/sensor_catalog_entry.dart';

class SensorCatalogRegistry {
  static List<SensorCatalogEntry> _entries = [];

  static List<SensorCatalogEntry> get entries => _entries;

  static void setEntries(List<SensorCatalogEntry> entries) {
    _entries = entries;
  }

  static void clear() {
    _entries = [];
  }

  static SensorCatalogEntry? findByKey(
    String key, {
    String? attribute,
    String? titleOverride,
    String? characteristicUuid,
  }) {
    final matches = _entries.where((entry) {
      if (entry.key != key) return false;
      if (attribute != null) {
        if (entry.attribute != attribute) return false;
      } else if (entry.attribute != null) {
        return false;
      }
      if (titleOverride != null && entry.uploadTitle != titleOverride) {
        return false;
      }
      if (characteristicUuid != null &&
          entry.characteristicUuid != null &&
          entry.characteristicUuid != characteristicUuid) {
        return false;
      }
      return true;
    }).toList();

    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    if (titleOverride != null) {
      return matches.firstWhere(
        (entry) => entry.uploadTitle == titleOverride,
        orElse: () => matches.first,
      );
    }

    return matches.first;
  }

  static SensorCatalogEntry? findByUploadTitle(String uploadTitle) {
    for (final entry in _entries) {
      if (entry.uploadTitle == uploadTitle) {
        return entry;
      }
    }
    return null;
  }

  static String? getUploadTitle(
    String key,
    String? attribute, {
    String? characteristicUuid,
  }) {
    final entry = findByKey(
      key,
      attribute: attribute,
      characteristicUuid: characteristicUuid,
    );
    return entry?.uploadTitle;
  }
}
