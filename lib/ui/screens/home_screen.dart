import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/permission_service.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

// HomeScreen now delegates sections to smaller widgets
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BleBloc bleBloc = Provider.of<BleBloc>(context);
    final RecordingBloc recordingBloc = Provider.of<RecordingBloc>(context);
    final SensorBloc sensorBloc = Provider.of<SensorBloc>(context);

    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.connectionErrorNotifier,
      builder: (context, error, child) {
        if (error == true && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).clearMaterialBanners();
            ScaffoldMessenger.of(context).showMaterialBanner(
              MaterialBanner(
                content: Text(
                    AppLocalizations.of(context)!.errorBleConnectionFailed),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                actions: [
                  TextButton(
                    onPressed: () {
                      bleBloc.resetConnectionError();
                      ScaffoldMessenger.of(context).clearMaterialBanners();
                    },
                    child: Text(
                        MaterialLocalizations.of(context).closeButtonLabel),
                  ),
                ],
              ),
            );
          });
        }

        return Scaffold(
          body: CustomScrollView(
            clipBehavior: Clip.none,
            slivers: [
              // SliverPersistentHeader with the map and floating buttons
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  minHeight: MediaQuery.of(context).size.height * 0.33,
                  maxHeight: MediaQuery.of(context).size.height *
                      (bleBloc.isConnected ? 0.65 : 0.85),
                  child: Stack(
                    children: [
                      const SizedBox(
                        width: double.infinity,
                        child: GeolocationMapWidget(), // The map
                      ),
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _BottomGradient(),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _FloatingButtons(
                              bleBloc: bleBloc, recordingBloc: recordingBloc),
                        ),
                      ),
                    ],
                  ),
                ),
                pinned: true,
              ),
              SliverSafeArea(
                minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                sliver: ValueListenableBuilder<BluetoothDevice?>(
                  valueListenable: bleBloc.selectedDeviceNotifier,
                  builder: (context, device, child) {
                    if (device == null) {
                      // Not connected: show nothing
                      return SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    // Connected: show sensor grid
                    return _SensorGrid(sensorBloc: sensorBloc);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget for senseBox selection as a badge-like button
class _SenseBoxSelectionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final OpenSenseMapBloc osemBloc = Provider.of<OpenSenseMapBloc>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!osemBloc.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<SenseBox?>(
      stream: osemBloc.senseBoxStream,
      initialData: osemBloc.selectedSenseBox,
      builder: (context, snapshot) {
        final selectedBox = snapshot.data;
        final bool hasError = snapshot.hasError;
        final bool noBox = selectedBox == null;

        Color textColor = hasError
            ? colorScheme.onErrorContainer
            : Theme.of(context).colorScheme.onTertiaryContainer;
        IconData icon = hasError
            ? Icons.error
            : noBox
                ? Icons.add_box_outlined
                : Icons.emergency_share_rounded;
        String label = hasError
            ? AppLocalizations.of(context)!.generalError
            : noBox
                ? AppLocalizations.of(context)!.selectOrCreateBox
                : selectedBox.name ?? '';

        return InkWell(
          onTap: () => showSenseBoxSelection(context, osemBloc),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: hasError
                  ? colorScheme.errorContainer
                  : Theme.of(context).colorScheme.tertiary,
              borderRadius: BorderRadius.circular(borderRadiusSmall),
              border: Border.all(
                color: hasError
                    ? colorScheme.outlineVariant
                    : Theme.of(context).colorScheme.tertiary,
                width: 1.0,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.03),
                  blurRadius: 1.5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon in a small circle background
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Center(
                    child: Icon(
                      icon,
                      color: hasError
                          ? colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onTertiaryContainer,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
                // Optional description (for error or noBox)
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.refresh,
                        color: colorScheme.onErrorContainer, size: 16),
                  )
                else if (noBox)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.arrow_forward,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                        size: 16),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Widget for floating action buttons
class _FloatingButtons extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  const _FloatingButtons({required this.bleBloc, required this.recordingBloc});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.isReconnectingNotifier,
      builder: (context, isReconnecting, child) {
        return ValueListenableBuilder(
          valueListenable: bleBloc.selectedDeviceNotifier,
          builder: (context, selectedDevice, child) {
            // Show buttons if device is connected or if reconnecting
            if (selectedDevice == null && !isReconnecting) {
              return Column(
                spacing: 12,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ConnectButton(bleBloc: bleBloc),
                  _SenseBoxSelectionButton(),
                ],
              );
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: [
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: _StartStopButton(recordingBloc: recordingBloc),
                      ),
                      Expanded(
                        child: _DisconnectButton(bleBloc: bleBloc),
                      ),
                    ],
                  ),
                  _SenseBoxSelectionButton(),
                ],
              );
            }
          },
        );
      },
    );
  }
}

// Connect button
class _ConnectButton extends StatelessWidget {
  final BleBloc bleBloc;
  const _ConnectButton({required this.bleBloc});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.isConnectingNotifier,
      builder: (context, isConnecting, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: bleBloc.isBluetoothEnabledNotifier,
          builder: (context, isBluetoothEnabled, child) {
            if (isConnecting) {
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: double.infinity, // Full width for the button
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12), // Vertical padding only
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.connectionButtonConnecting,
                    ),
                    icon: const Loader(),
                    onPressed: null, // Disable button while connecting
                  ),
                ),
              );
            } else {
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: double.infinity, // Set a fixed width for the button
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isBluetoothEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface, // Disabled color
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: Text(
                      isBluetoothEnabled
                          ? AppLocalizations.of(context)!
                              .connectionButtonConnect
                          : AppLocalizations.of(context)!
                              .connectionButtonEnableBluetooth,
                      style: TextStyle(
                        color: isBluetoothEnabled
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context)
                                .colorScheme
                                .error, // Red text if Bluetooth is off
                      ),
                    ),
                    icon: Icon(
                      Icons.bluetooth,
                      color: isBluetoothEnabled
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .error, // Red icon if Bluetooth is off
                    ),
                    onPressed: () async {
                      if (isBluetoothEnabled) {
                        // Show device selection dialog if Bluetooth is enabled
                        showDeviceSelectionDialog(context, bleBloc);
                      } else {
                        try {
                          await bleBloc.requestEnableBluetooth();
                        } catch (e) {
                          ErrorService.handleError(e, StackTrace.current);
                        }
                      }
                    },
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// Start/Stop button
class _StartStopButton extends StatelessWidget {
  final RecordingBloc recordingBloc;
  const _StartStopButton({required this.recordingBloc});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      label: Text(recordingBloc.isRecording
          ? AppLocalizations.of(context)!.connectionButtonStop
          : AppLocalizations.of(context)!.connectionButtonStart),
      icon: Icon(
          recordingBloc.isRecording ? Icons.stop : Icons.fiber_manual_record),
      onPressed: () async {
        try {
          await PermissionService.ensureLocationPermissionsGranted();
          recordingBloc.isRecording
              ? recordingBloc.stopRecording()
              : recordingBloc.startRecording();
        } catch (e) {
          ErrorService.handleError(e, StackTrace.current);
        }
      },
    );
  }
}

// Disconnect button
class _DisconnectButton extends StatelessWidget {
  final BleBloc bleBloc;
  const _DisconnectButton({required this.bleBloc});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.isReconnectingNotifier,
      builder: (context, isReconnecting, child) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          icon: isReconnecting
              ? const Icon(Icons.bluetooth_searching)
              : const Icon(Icons.bluetooth_disabled),
          label: isReconnecting
              ? Text(AppLocalizations.of(context)!.connectionButtonReconnecting)
              : Text(AppLocalizations.of(context)!.connectionButtonDisconnect),
          onPressed: isReconnecting ? null : bleBloc.disconnectDevice,
        );
      },
    );
  }
}

// Bottom gradient widget
class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        height: 100,
      ),
    );
  }
}

// Widget for the sensor grid
class _SensorGrid extends StatelessWidget {
  final SensorBloc sensorBloc;
  const _SensorGrid({required this.sensorBloc});

  @override
  Widget build(BuildContext context) {
    final widgets = sensorBloc.getSensorWidgets();
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return index < widgets.length ? widgets[index] : null;
        },
        childCount: widgets.length,
      ),
    );
  }
}

// SliverAppBarDelegate remains unchanged
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
