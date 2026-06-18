import 'package:app_settings/app_settings.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

bool isBluetoothAdapterEnabled(BleAdapterState status) =>
    status == BleAdapterState.ready;

class BleAdapter {
  BleAdapter({required BlePlatform platform}) : _platform = platform;

  final BlePlatform _platform;

  Future<void> configure() => _platform.initialize();

  Stream<BleAdapterState> get statusStream => _platform.statusStream;

  Future<bool> isEnabled() async {
    final status = await _platform.statusStream.firstWhere(
      (state) => state != BleAdapterState.unknown,
    );
    return isBluetoothAdapterEnabled(status);
  }

  Future<void> requestEnable() =>
      AppSettings.openAppSettings(type: AppSettingsType.bluetooth);

  /// Opens the app's system settings page so the user can grant a permission
  /// that was denied (used when Bluetooth runtime permissions are unavailable).
  Future<void> openAppSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.settings);
}
