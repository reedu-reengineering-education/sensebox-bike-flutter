import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';

void main() {
  group('bleConnectionFailureMessage', () {
    late AppLocalizations localizations;

    setUp(() {
      localizations = lookupAppLocalizations(const Locale('en'));
    });

    test('maps noService to incompatible device message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.noService,
        ),
        localizations.errorBleIncompatibleDevice,
      );
    });

    test('maps noCharacteristics to incompatible device message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.noCharacteristics,
        ),
        localizations.errorBleIncompatibleDevice,
      );
    });

    test('maps noData to no sensor data message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.noData,
        ),
        localizations.errorBleNoSensorData,
      );
    });

    test('maps invalidData to invalid sensor data message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.invalidData,
        ),
        localizations.errorBleInvalidSensorData,
      );
    });

    test('maps connectionTimeout to timeout message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.connectionTimeout,
        ),
        localizations.errorBleConnectionTimeout,
      );
    });

    test('maps connectionLost to connection lost message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.connectionLost,
        ),
        localizations.errorBleConnectionLost,
      );
    });

    test('maps bluetoothError to generic connection failed message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.bluetoothError,
        ),
        localizations.errorBleConnectionFailed,
      );
    });

    test('maps null to generic connection failed message', () {
      expect(
        bleConnectionFailureMessage(localizations, null),
        localizations.errorBleConnectionFailed,
      );
    });
  });
}
