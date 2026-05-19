import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';

String bleConnectionFailureMessage(
  AppLocalizations localizations,
  BleConnectionFailureReason? reason,
) {
  switch (reason) {
    case BleConnectionFailureReason.noService:
    case BleConnectionFailureReason.noCharacteristics:
      return localizations.errorBleIncompatibleDevice;
    case BleConnectionFailureReason.noData:
      return localizations.errorBleNoSensorData;
    case BleConnectionFailureReason.invalidData:
      return localizations.errorBleInvalidSensorData;
    case BleConnectionFailureReason.connectionTimeout:
      return localizations.errorBleConnectionTimeout;
    case BleConnectionFailureReason.connectionLost:
      return localizations.errorBleConnectionLost;
    case BleConnectionFailureReason.bluetoothError:
    case null:
      return localizations.errorBleConnectionFailed;
  }
}

Future<void> handleBleConnectionResult({
  required BuildContext context,
  required BluetoothDevice device,
  required BleConnectionResult result,
}) async {
  if (result.success) {
    return;
  }

  if (!context.mounted) return;

  await showBleConnectionFailedDialog(context, result.failureReason);
}

Future<void> showRecordingStoppedDueToBleDialog(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;

  return showAppDialog(
    context: context,
    title: localizations.recordingStoppedBleDisconnectTitle,
    message: localizations.recordingStoppedBleDisconnectBody,
    type: AppDialogType.info,
  ).then((_) {});
}

Future<void> showBleConnectionFailedDialog(
  BuildContext context,
  BleConnectionFailureReason? reason,
) {
  final localizations = AppLocalizations.of(context)!;

  return showAppDialog(
    context: context,
    title: localizations.errorBleConnectionAttemptFailedTitle,
    message: localizations.errorBleConnectionAttemptFailed,
    type: AppDialogType.error,
  ).then((_) {});
}
