import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) async {
  Object? scanError;

  try {
    await bleBloc.startScanning();
  } catch (e) {
    scanError = e;
  }

  showDialog<void>(
    context: context,
      builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.bleDeviceSelectTitle),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                height: 400,
                width: 350, // Optionally set a width
                child: DeviceSelectionSheet(
                  bleBloc: bleBloc,
                  initialScanError: scanError,
                ),
              ),
              actions: [
                TextButton(
                    child: Text(AppLocalizations.of(context)!.generalCancel),
                    onPressed: () {
                      Navigator.pop(context);
                      bleBloc.stopScanning();
                    })
              ])
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
        child: StreamBuilder<List<BluetoothDevice>>(
          stream: widget.bleBloc.devicesListStream,
          builder: (context, snapshot) {
            final colorScheme = Theme.of(context).colorScheme;

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Center(
                        child: CircularProgressIndicator(
                      color: colorScheme.primaryFixedDim));
            }

            if (snapshot.hasError) {
              return Center(
                child: Text("Stream Error: ${snapshot.error.toString()}"),
              );
            }

            final devices = snapshot.data;

            if (devices == null || devices.isEmpty) {
              return ValueListenableBuilder<bool>(
                valueListenable: widget.bleBloc.isScanningNotifier,
                builder: (context, isScanning, child) {
                  final colorScheme = Theme.of(context).colorScheme;
                  if (isScanning) {
                    return Center(
                              child: CircularProgressIndicator(
                            color: colorScheme.primaryFixedDim));
                  } else {
                    // Not scanning, and no devices found.
                    return Center(
                      child: Text(localizations.noBleDevicesFound),
                    );
                  }
                },
              );
            }

            return ListView.separated(
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: spacing * 2),
                child: Divider(
                  height: 1,
                  color: colorScheme.primaryFixedDim,
                ),
              ),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final deviceName = device.platformName.isNotEmpty
                    ? device.platformName
                    : "(Unknown)";
                return ClickableTile(
                  child: Text(deviceName),
                  onTap: () {
                    widget.bleBloc.connectToDevice(device, context);
                    Navigator.pop(context);
                  },
                );
              },
            );
          },
        )
    );
  }
}
