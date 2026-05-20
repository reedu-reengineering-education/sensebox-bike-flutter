import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/common/app_dialog.dart';
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

  return showAppDialog(
    context: context,
    title: localizations.blePartialConnectionTitle,
    message: localizations.blePartialConnectionBody(failedNames),
    type: AppDialogType.confirmation,
    cancelLabel: localizations.blePartialConnectionCancel,
    confirmLabel: localizations.blePartialConnectionContinue,
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
      final finalizeResult =
          await bleBloc.finalizePartialConnection(device, context);
      if (!context.mounted) return;

      if (!finalizeResult.success) {
        bleBloc.disconnectDevice();
        await showBleConnectionFailedDialog(
          context,
          finalizeResult.failureReason,
        );
      }
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
    message: bleConnectionFailureMessage(localizations, reason),
    type: AppDialogType.error,
  ).then((_) {});
}
