import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_scanner.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/clickable_tile.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_divider.dart';
import 'package:sensebox_bike/ui/widgets/common/empty_state_message.dart';
import 'package:sensebox_bike/ui/widgets/common/surface_outlined_icon_button.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) async {
  final selected = await showModalBottomSheet<bool>(
    showDragHandle: true,
    isScrollControlled: true,
    context: context,
    builder: (sheetContext) => _BleDeviceSelectionBottomSheet(
      bleBloc: bleBloc,
    ),
  );

  if (selected != true) {
    await bleBloc.stopScanning();
  }
}

class _BleDeviceSelectionBottomSheet extends StatefulWidget {
  final BleBloc bleBloc;

  const _BleDeviceSelectionBottomSheet({required this.bleBloc});

  @override
  State<_BleDeviceSelectionBottomSheet> createState() =>
      _BleDeviceSelectionBottomSheetState();
}

class _BleDeviceSelectionBottomSheetState
    extends State<_BleDeviceSelectionBottomSheet> {
  Object? _scanError;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    try {
      await widget.bleBloc.startScanning();
      if (mounted) {
        setState(() => _scanError = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanError = e);
      }
    }
  }

  void _onShowRetryChanged(bool showRetry) {
    if (_showRetry != showRetry) {
      setState(() => _showRetry = showRetry);
    }
  }

  bool get _useRetryButton => _scanError != null || _showRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          localizations.bleDeviceSelectTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        DeviceSelectionSheet(
          bleBloc: widget.bleBloc,
          scanError: _scanError,
          onShowRetryChanged: _onShowRetryChanged,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: spacing,
            right: spacing,
            top: spacing,
            bottom: spacing * 2 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: SurfaceOutlinedIconButton(
            icon: _useRetryButton ? Icons.refresh : Icons.close,
            label: _useRetryButton
                ? localizations.generalRetry
                : localizations.generalCancel,
            onPressed: () async {
              if (_useRetryButton) {
                setState(() => _scanError = null);
                await _startScan();
              } else {
                await widget.bleBloc.stopScanning();
                if (context.mounted) {
                  Navigator.pop(context, false);
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class DeviceSelectionSheet extends StatefulWidget {
  final BleBloc bleBloc;
  final Object? scanError;
  final ValueChanged<bool>? onShowRetryChanged;

  const DeviceSelectionSheet({
    super.key,
    required this.bleBloc,
    this.scanError,
    this.onShowRetryChanged,
  });

  @override
  State<DeviceSelectionSheet> createState() => _DeviceSelectionSheetState();
}

class _DeviceSelectionSheetState extends State<DeviceSelectionSheet> {
  bool? _lastReportedRetry;

  void _reportShowRetry(bool showRetry) {
    if (_lastReportedRetry == showRetry) {
      return;
    }
    _lastReportedRetry = showRetry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onShowRetryChanged?.call(showRetry);
    });
  }

  bool _shouldShowRetry({
    required bool isScanning,
    required AsyncSnapshot<List<BleDevice>> snapshot,
  }) {
    if (widget.scanError != null) {
      return true;
    }
    if (snapshot.hasError) {
      return true;
    }
    final devices = snapshot.data;
    if (devices == null || devices.isEmpty) {
      return !isScanning;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (widget.scanError != null) {
      _reportShowRetry(true);
      return Padding(
        padding: const EdgeInsets.only(
          top: spacing * 4,
          bottom: spacing,
          left: spacing,
          right: spacing,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Text(
              widget.scanError.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: spacing * 4,
        bottom: spacing,
        left: spacing,
        right: spacing,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListenableBuilder(
          listenable: widget.bleBloc.isScanningNotifier,
          builder: (context, _) {
            return StreamBuilder<List<BleDevice>>(
              stream: widget.bleBloc.devicesListStream,
              initialData: widget.bleBloc.devicesList,
              builder: (context, snapshot) {
                final colorScheme = Theme.of(context).colorScheme;
                final isScanning = widget.bleBloc.isScanningNotifier.value;

                _reportShowRetry(
                  _shouldShowRetry(isScanning: isScanning, snapshot: snapshot),
                );

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
                  if (isScanning) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primaryFixedDim,
                      ),
                    );
                  }
                  return EmptyStateMessage(
                    icon: Icons.sensors_off_outlined,
                    message: localizations.noBleDevicesFound,
                  );
                }

                return ListView.separated(
                  separatorBuilder: (context, index) =>
                      CustomDivider(showDivider: true),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ClickableTile(
                      child: Text(bleDevicePickerLabel(device)),
                      onTap: () async {
                        await widget.bleBloc.connectToDevice(device, context);
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
