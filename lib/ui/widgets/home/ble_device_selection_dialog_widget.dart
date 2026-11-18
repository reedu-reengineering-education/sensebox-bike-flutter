import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';
import 'package:sensebox_bike/ui/widgets/common/empty_state_message.dart';
import 'package:sensebox_bike/ui/widgets/common/modal_sheet_style.dart';
import 'package:sensebox_bike/ui/widgets/common/surface_outlined_icon_button.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) {
  showAppModalSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => DeviceSelectionSheet(bleBloc: bleBloc),
  );
}

class DeviceSelectionSheet extends StatefulWidget {
  final BleBloc bleBloc;

  const DeviceSelectionSheet({super.key, required this.bleBloc});

  @override
  State<DeviceSelectionSheet> createState() => _DeviceSelectionSheetState();
}

class _DeviceSelectionSheetState extends State<DeviceSelectionSheet> {
  late Stream<List<BleDevice>> _devices = widget.bleBloc.scanForDevices();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<BleDevice>>(
      stream: _devices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? const <BleDevice>[];
        final scanning = !snapshot.hasError &&
            snapshot.connectionState != ConnectionState.done;
        final showRetry = !scanning && devices.isEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations.bleDeviceSelectTitle,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: spacing * 4,
                bottom: spacing,
                left: spacing,
                right: spacing,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _DeviceList(
                  bleBloc: widget.bleBloc,
                  snapshot: snapshot,
                  scanning: scanning,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: spacing,
                right: spacing,
                top: spacing,
                bottom: spacing * 2 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: SurfaceOutlinedIconButton(
                icon: showRetry ? Icons.refresh : Icons.close,
                label: showRetry
                    ? localizations.generalRetry
                    : localizations.generalCancel,
                onPressed: () {
                  if (showRetry) {
                    setState(() => _devices = widget.bleBloc.scanForDevices());
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DeviceList extends StatelessWidget {
  final BleBloc bleBloc;
  final AsyncSnapshot<List<BleDevice>> snapshot;
  final bool scanning;

  const _DeviceList({
    required this.bleBloc,
    required this.snapshot,
    required this.scanning,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Stream Error: ${snapshot.error}',
          style: TextStyle(color: colorScheme.error),
        ),
      );
    }

    final devices = snapshot.data ?? const <BleDevice>[];
    if (devices.isEmpty) {
      if (scanning) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primaryFixedDim),
        );
      }
      return EmptyStateMessage(
        icon: Icons.sensors_off_outlined,
        message: localizations.noBleDevicesFound,
      );
    }

    return ListenableBuilder(
      listenable: bleBloc.settingsBloc,
      builder: (context, _) {
        final rememberedId = bleBloc.settingsBloc.rememberedDeviceId;

        return ListView.separated(
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final isRemembered = device.id == rememberedId;

            return ClickableTile(
              onTap: () {
                bleBloc.connectToDevice(device);
                Navigator.pop(context);
              },
              trailing: _DeviceOptionsMenu(
                bleBloc: bleBloc,
                device: device,
                isRemembered: isRemembered,
              ),
              child: isRemembered
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(bleDevicePickerLabel(device)),
                        Text(
                          localizations.bleDeviceAutoConnectBadge,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    )
                  : Text(bleDevicePickerLabel(device)),
            );
          },
        );
      },
    );
  }
}

enum _DeviceOption { remember, forget }

class _DeviceOptionsMenu extends StatelessWidget {
  final BleBloc bleBloc;
  final BleDevice device;
  final bool isRemembered;

  const _DeviceOptionsMenu({
    required this.bleBloc,
    required this.device,
    required this.isRemembered,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return PopupMenuButton<_DeviceOption>(
      icon: const Icon(Icons.more_vert),
      tooltip: localizations.bleDeviceMoreOptions,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onSelected: (option) {
        switch (option) {
          case _DeviceOption.remember:
            bleBloc.settingsBloc.rememberDevice(device.id, device.name);
            break;
          case _DeviceOption.forget:
            bleBloc.settingsBloc.forgetRememberedDevice();
            break;
        }
      },
      itemBuilder: (context) => [
        if (isRemembered)
          PopupMenuItem(
            value: _DeviceOption.forget,
            child: Text(localizations.bleDeviceForgetDevice),
          )
        else
          PopupMenuItem(
            value: _DeviceOption.remember,
            child: Text(localizations.bleDeviceRememberDevice),
          ),
      ],
    );
  }
}
