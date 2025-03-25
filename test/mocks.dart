import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';

class MockIsarService extends IsarService {
  List<TrackData> mockTracks = []; 
  @override
  TrackService get trackService => MockTrackService(mockTracks);
}

class MockTrackService extends TrackService {
  final List<TrackData> tracks;

  MockTrackService(this.tracks);
  @override
  Future<List<TrackData>> getAllTracks() async {
    return tracks; 
  }
}

class MockTrackData extends TrackData {
  @override
  Duration get duration => const Duration(minutes: 30);

  @override
  double get distance => 1000;
}

class MockGeolocation extends GeolocationData {
  @override
  DateTime get timestamp => DateTime.now();
}

class MockOpenSenseMapBloc extends OpenSenseMapBloc {
  @override
  bool isAuthenticated = false;

  @override
  Future<void> logout() async {
    isAuthenticated = false;
  }
}

class MockPathProviderPlatform extends PathProviderPlatform {
  Future<String?> getApplicationDocumentsPath() async {
    return '/data/user/0/com.example.app/files'; // Android-like path
  }

  Future<String?> getTemporaryPath() async {
    return '/data/user/0/com.example.app/cache'; // Android-like path
  }
}
