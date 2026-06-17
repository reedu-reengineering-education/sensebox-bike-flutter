import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';

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

Future<bool> showBlePartialConnectionDialog(
  BuildContext context,
  BleConnectionResult result,
) {
  final localizations = AppLocalizations.of(context)!;
  final failedNames = result.failedUuids
      .map(getSensorDisplayNameByUuid)
      .toSet()
      .join(', ');

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(localizations.blePartialConnectionTitle),
        content: Text(
          localizations.blePartialConnectionBody(failedNames),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.blePartialConnectionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.blePartialConnectionContinue),
          ),
        ],
      );
    },
  ).then((value) => value ?? false);
}

Future<void> handleBleConnectionResult({
  required BuildContext context,
  required BleBloc bleBloc,
  required BluetoothDevice device,
  required BleConnectionResult result,
}) async {
  if (result.success) {
    return;
  }

  if (result.needsUserDecision) {
    if (!context.mounted) return;

    final shouldContinue = await showBlePartialConnectionDialog(context, result);
    if (!context.mounted) return;

    if (shouldContinue) {
      await bleBloc.finalizePartialConnection(device, context);
    } else {
      bleBloc.disconnectDevice();
    }
    return;
  }

  if (!context.mounted) return;

  await showBleConnectionFailedDialog(context, result.failureReason);
}

Future<void> showRecordingStoppedDueToBleDialog(BuildContext context) {
  final localizations = AppLocalizations.of(context)!;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(localizations.recordingStoppedBleDisconnectTitle),
        content: Text(localizations.recordingStoppedBleDisconnectBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.generalOk),
          ),
        ],
      );
    },
  );
}

Future<void> showBleConnectionFailedDialog(
  BuildContext context,
  BleConnectionFailureReason? reason,
) {
  final localizations = AppLocalizations.of(context)!;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(localizations.errorBleConnectionAttemptFailedTitle),
        content: Text(localizations.errorBleConnectionAttemptFailed),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.generalOk),
          ),
        ],
      );
    },
  );
}
