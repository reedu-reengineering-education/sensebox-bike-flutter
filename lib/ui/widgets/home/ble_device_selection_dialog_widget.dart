import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) async {
  Object? scanError;

  try {
    await bleBloc.startScanning();
  } catch (e) {
    scanError = e;
  }

  showModalBottomSheet<void>(
    showDragHandle: true,
    context: context,
    isScrollControlled: true,
    builder: (BuildContext modalContext) {
      return DeviceSelectionSheet(
          bleBloc: bleBloc, initialScanError: scanError);
    },
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            localizations.bleDeviceSelectTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const CustomSpacer(),
          if (widget.initialScanError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  "Error starting scan: ${widget.initialScanError.toString()}",
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: StreamBuilder<List<BluetoothDevice>>(
                stream: widget.bleBloc.devicesListStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
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
                        if (isScanning) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else {
                          // Not scanning, and no devices found.
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(localizations.noBleDevicesFound),
                            ),
                          );
                        }
                      },
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
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
                    separatorBuilder: (context, index) => const CustomSpacer(), 
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;

  const _DeviceListItem({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
          device.platformName.isNotEmpty ? device.platformName : "(Unknown)"),
      trailing: const Icon(Icons.arrow_forward),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      onTap: onTap,
    );
  }
}
