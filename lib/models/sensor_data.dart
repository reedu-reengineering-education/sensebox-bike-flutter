import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:isar_community/isar.dart';

part 'sensor_data.g.dart';

@Collection()
class SensorData {
  Id id = Isar.autoIncrement;

  late String characteristicUuid;
  late String title;
  late String? attribute;
  late double value;

  final geolocationData = IsarLink<GeolocationData>();
}
