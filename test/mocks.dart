import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/services/isar_service/geolocation_service.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:sensebox_bike/services/isar_service/sensor_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/tag_service.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/sensors/sensor.dart' as sensors;
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIsarProvider extends Mock implements IsarProvider {}

class MockTagService extends Mock implements TagService {}

class MockErrorService extends Mock implements ErrorService {}

class MockIsarService extends Mock implements IsarService {
  final MockTrackService mockTrackService = MockTrackService();

  @override
  TrackService get trackService => mockTrackService;
}

class MockTrackService extends Mock implements TrackService {}

class MockGeolocationService extends Mock implements GeolocationService {}

class MockSensorService extends Mock implements SensorService {}

class MockBleBloc extends Mock implements BleBloc {
  final List<VoidCallback> _listeners = [];

  @override
  final ValueNotifier<bool> isBluetoothEnabledNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isConnectingNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<BluetoothDevice?> selectedDeviceNotifier =
      ValueNotifier(null);

  @override
  final ValueNotifier<List<BluetoothCharacteristic>> availableCharacteristics =
      ValueNotifier([]);

  @override
  final ValueNotifier<int> characteristicStreamsVersion = ValueNotifier(0);

  @override
  final ValueNotifier<bool> connectionErrorNotifier = ValueNotifier(false);

  @override
  bool get isConnected => false;

  @override
  List<BluetoothDevice> get devicesList => [];

  @override
  Stream<List<BluetoothDevice>> get devicesListStream => Stream.value([]);

  @override
  BluetoothDevice? get selectedDevice => selectedDeviceNotifier.value;

  @override
  set selectedDevice(BluetoothDevice? device) {
    selectedDeviceNotifier.value = device;
  }

  @override
  Future<void> connectToDevice(
      BluetoothDevice device, BuildContext context) async {}

  @override
  void disconnectDevice() {}

  @override
  Future<void> startScanning() async {}

  @override
  Future<void> scanForNewDevices() async {
    selectedDevice = null;
    selectedDeviceNotifier.value = null;
  }

  @override
  void resetConnectionError() {
    connectionErrorNotifier.value = false;
  }

  @override
  void updateBluetoothStatus(bool isEnabled) {
    isBluetoothEnabledNotifier.value = isEnabled;
    notifyListeners();
  }

  @override
  Future<void> requestEnableBluetooth() async {}

  @override
  Stream<List<double>> getCharacteristicStream(String characteristicUuid) =>
      Stream.value([]);

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void dispose() {}

  @override
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  ValueNotifier<bool> get permanentConnectionLossNotifier =>
      ValueNotifier<bool>(false);
}

class MockTrackBloc extends Mock with ChangeNotifier implements TrackBloc {}

class MockGeolocationBloc extends Mock implements GeolocationBloc {}

class MockOpenSenseMapBloc extends Mock
    with ChangeNotifier
    implements OpenSenseMapBloc {
  @override
  bool isAuthenticated = false;

  @override
  bool get isAuthenticating => false;

  @override
  SenseBox? get selectedSenseBox => null;

  @override
  Stream<SenseBox?> get senseBoxStream => Stream.value(null);

  @override
  List<dynamic> get senseBoxes => [];

  @override
  Future<void> logout() async {
    isAuthenticated = false;
  }

  @override
  Future<void> markAuthenticationFailed() async {
    isAuthenticated = false;
  }

  @override
  Future<Map<String, dynamic>?> getUserData() async {
    if (!isAuthenticated) {
      return null;
    }
    return {
      'data': {
        'me': {
          'email': 'test@example.com',
          'name': 'Test User',
        }
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> get userData => Future.value(null);
}

class MockSettingsBloc extends Mock
    with ChangeNotifier
    implements SettingsBloc {}

class MockRecordingBloc extends Mock implements RecordingBloc {
  bool _isRecording = false;
  late final ValueNotifier<bool> _isRecordingNotifier;

  MockRecordingBloc() {
    _isRecordingNotifier = ValueNotifier<bool>(_isRecording);
  }

  @override
  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    _isRecordingNotifier.value = value;
  }

  @override
  ValueNotifier<bool> get isRecordingNotifier => _isRecordingNotifier;
}

class MockSensorBloc extends Mock implements SensorBloc {
  Map<String, List<SensorData>> get sensorData => {};
}

class MockGeolocator extends Mock
    with MockPlatformInterfaceMixin
    implements geo.GeolocatorPlatform {}

class MockSensor extends Mock implements sensors.Sensor {}

class FakeSensorData extends Fake implements SensorData {}

// Track creation helpers for tests
class TestTrackBuilder {
  static TrackData createTrack({
    int? id,
    int? isDirectUpload,
    int? uploaded,
    int? uploadAttempts,
    DateTime? lastUploadAttempt,
    List<GeolocationData>? geolocations,
  }) {
    final track = TrackData()
      ..id = id ?? 1
      ..isDirectUpload = isDirectUpload ?? 1
      ..uploaded = uploaded ?? 0
      ..uploadAttempts = uploadAttempts ?? 0
      ..lastUploadAttempt = lastUploadAttempt;

    if (geolocations != null) {
      track.geolocations.addAll(geolocations);
    }

    return track;
  }

  static GeolocationData createGeolocation({
    int? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? speed,
  }) {
    return GeolocationData()
      ..id = id ?? 1
      ..latitude = latitude ?? 52.5200
      ..longitude = longitude ?? 13.4050
      ..timestamp = timestamp ?? DateTime.now()
      ..speed = speed ?? 0.0;
  }
}

// Mocks for webview_flutter

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return FakeWebViewWidget(params);
  }

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) {
    return FakeCookieManager(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return FakeNavigationDelegate(params);
  }
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(
      JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<String?> currentUrl() async {
    return 'https://www.google.com';
  }
}

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params) : super.implementation();
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const Text('Fake WebView Content', key: Key('FakeWebViewWidget'));
  }
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
