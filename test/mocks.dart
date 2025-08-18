
import 'package:flutter/material.dart';
import 'package:mockito/mockito.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
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
  @override
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

class MockSensor extends Mock implements sensors.Sensor {}
class FakeSensorData extends mocktail.Fake implements SensorData {}

// Mocks for webview_flutter

class FakeWebViewPlatform extends mocktail.Fake implements WebViewPlatform {
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

class FakeWebViewController extends mocktail.Fake implements PlatformWebViewController {
  FakeWebViewController(PlatformWebViewControllerCreationParams params);

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

class FakeCookieManager extends mocktail.Fake implements PlatformWebViewCookieManager {
  FakeCookieManager(PlatformWebViewCookieManagerCreationParams params);
}

class FakeWebViewWidget extends mocktail.Fake implements PlatformWebViewWidget {
  FakeWebViewWidget(PlatformWebViewWidgetCreationParams params);

  @override
  Widget build(BuildContext context) {
    return const Text('Fake WebView Content', key: Key('FakeWebViewWidget'));
  }
}

class FakeNavigationDelegate extends mocktail.Fake implements PlatformNavigationDelegate {
  FakeNavigationDelegate(PlatformNavigationDelegateCreationParams params);

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
