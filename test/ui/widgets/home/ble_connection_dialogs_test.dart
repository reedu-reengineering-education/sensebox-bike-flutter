import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';

import '../../../test_helpers.dart';

void main() {
  setUpAll(() {
    initializeTestDependencies();
  });

  group('bleConnectionFailureMessage', () {
    late AppLocalizations localizations;

    setUp(() async {
      localizations = await AppLocalizations.delegate.load(const Locale('en'));
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

    test('maps connectionTimeout to timeout message', () {
      expect(
        bleConnectionFailureMessage(
          localizations,
          BleConnectionFailureReason.connectionTimeout,
        ),
        localizations.errorBleConnectionTimeout,
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
