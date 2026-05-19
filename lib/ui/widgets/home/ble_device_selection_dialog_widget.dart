import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_divider.dart';
import 'package:sensebox_bike/ui/widgets/common/empty_state_message.dart';
import 'package:sensebox_bike/models/ble_connection_result.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';

class BleDeviceConnectionAttempt {
  final BluetoothDevice device;
  final BleConnectionResult result;

  const BleDeviceConnectionAttempt({
    required this.device,
    required this.result,
  });
}

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) async {
  Object? scanError;

  try {
    await bleBloc.startScanning();
  } catch (e) {
    scanError = e;
  }

  final attempt = await showModalBottomSheet<BleDeviceConnectionAttempt?>(
      showDragHandle: true,
      isScrollControlled: true,
      context: context,
      builder: (context) => (Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              AppLocalizations.of(context)!.bleDeviceSelectTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            DeviceSelectionSheet(bleBloc: bleBloc, initialScanError: scanError),
          ])));

  if (attempt == null) {
    bleBloc.stopScanning();
    return;
  }

  if (!context.mounted) return;

  await handleBleConnectionResult(
    context: context,
    device: attempt.device,
    result: attempt.result,
  );
}

class DeviceSelectionSheet extends StatefulWidget {
  final BleBloc bleBloc;
  final Object? initialScanError;

  const DeviceSelectionSheet({
    super.key,
    required this.bleBloc,
    this.initialScanError,
  });

  @override
  State<DeviceSelectionSheet> createState() => _DeviceSelectionSheetState();
}

class _DeviceSelectionSheetState extends State<DeviceSelectionSheet> {
  bool _isConnecting = false;

  Future<void> _onDeviceTap(BluetoothDevice device) async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    final result = await widget.bleBloc.connectToDevice(device);

    if (!mounted) return;

    setState(() => _isConnecting = false);

    if (!mounted) return;

    Navigator.pop(
      context,
      BleDeviceConnectionAttempt(device: device, result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (widget.initialScanError != null) {
      return Center(
        child: Text(
          widget.initialScanError.toString(),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return Padding(
        padding: const EdgeInsets.only(
            top: spacing * 4, bottom: spacing, left: spacing, right: spacing),
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: ValueListenableBuilder<List<BluetoothDevice>>(
              valueListenable: widget.bleBloc.discoveredDevicesNotifier,
              builder: (context, devices, child) {
                final colorScheme = Theme.of(context).colorScheme;

                if (devices.isEmpty) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.bleBloc.isScanningNotifier,
                    builder: (context, isScanning, child) {
                      if (isScanning) {
                        return Center(
                            child: CircularProgressIndicator(
                                color: colorScheme.primaryFixedDim));
                      } else {
                        return EmptyStateMessage(
                          icon: Icons.sensors_off_outlined,
                          message: localizations.noBleDevicesFound,
                        );
                      }
                    },
                  );
                }

                if (_isConnecting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primaryFixedDim,
                    ),
                  );
                }

                return ListView.separated(
                  separatorBuilder: (context, index) =>
                      CustomDivider(showDivider: true),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final deviceName = device.platformName.isNotEmpty
                        ? device.platformName
                        : "(Unknown)";
                    return ClickableTile(
                      child: Text(deviceName),
                      onTap: () => _onDeviceTap(device),
                    );
                  },
                );
              },
            )));
  }
}
