import 'dart:convert';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:turf/turf.dart' as Turf;

class PrivacyZoneChecker {
  List<String> _cachedPrivacyZoneStrings = [];
  List<Turf.Polygon> _cachedPolygons = [];

  PrivacyZoneChecker();

  void updatePrivacyZones(List<String> privacyZoneStrings) {
    _cachedPrivacyZoneStrings = List.from(privacyZoneStrings);
    _cachedPolygons = _convertToTurfPolygons(privacyZoneStrings);
  }

  bool isInsidePrivacyZone(GeolocationData geolocation) {
    if (_cachedPolygons.isEmpty) {
      return false;
    }

    final point = Turf.Position(geolocation.longitude, geolocation.latitude);

    for (final zone in _cachedPolygons) {
      if (Turf.booleanPointInPolygon(point, zone)) {
        return true;
      }
    }

    return false;
  }

  List<Turf.Polygon> _convertToTurfPolygons(List<String> privacyZoneStrings) {
    final List<Turf.Polygon> turfPolygons = [];

    for (final zoneString in privacyZoneStrings) {
      try {
        final zoneJson = jsonDecode(zoneString) as Map<String, dynamic>;
        final coordinates = zoneJson['coordinates'] as List<dynamic>?;

        if (coordinates == null || coordinates.isEmpty) {
          continue;
        }

        final outerRing = coordinates[0] as List<dynamic>;
        if (outerRing.isEmpty) {
          continue;
        }

        final turfCoordinates = outerRing.map((coord) {
          final coordList = coord as List<dynamic>;
          return Turf.Position(
            (coordList[0] as num).toDouble(),
            (coordList[1] as num).toDouble(),
          );
        }).toList();

        final closedCoordinates = _closePolygon(turfCoordinates);
        turfPolygons.add(Turf.Polygon(coordinates: [closedCoordinates]));
      } catch (e) {
        continue;
      }
    }

    return turfPolygons;
  }

  List<Turf.Position> _closePolygon(List<Turf.Position> coordinates) {
    if (coordinates.isEmpty) {
      return coordinates;
    }

    final first = coordinates.first;
    final last = coordinates.last;

    if (first.lng != last.lng || first.lat != last.lat) {
      return [...coordinates, first];
    }

    return coordinates;
  }

  void dispose() {
    _cachedPolygons.clear();
    _cachedPrivacyZoneStrings.clear();
  }
}
