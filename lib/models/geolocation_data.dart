import 'package:isar/isar.dart';

part 'geolocation_data.g.dart';

@Collection()
class GeolocationData {
  Id id = Isar.autoIncrement;

  late double latitude;
  late double longitude;
  late double speed;
  late DateTime timestamp;
}
