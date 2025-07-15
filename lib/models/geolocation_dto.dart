// lib/models/geolocation_dto.dart
class GeolocationDto {
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;
  final int trackId;

  GeolocationDto({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
    required this.trackId,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'timestamp': timestamp.toIso8601String(),
    'trackId': trackId,
  };

  static GeolocationDto fromJson(Map<String, dynamic> json) => GeolocationDto(
    latitude: json['latitude'],
    longitude: json['longitude'],
    speed: json['speed'],
    timestamp: DateTime.parse(json['timestamp']),
    trackId: json['trackId'],
  );
}