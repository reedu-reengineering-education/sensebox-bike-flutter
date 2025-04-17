import 'dart:math';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/ui/utils/common.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// HomeScreen now delegates sections to smaller widgets
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BleBloc bleBloc = Provider.of<BleBloc>(context);
    final RecordingBloc recordingBloc = Provider.of<RecordingBloc>(context);
    final SensorBloc sensorBloc = Provider.of<SensorBloc>(context);

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
            sliver: _SensorGrid(sensorBloc: sensorBloc),
          ),
        ],
      ),
    );
  }
}

// Widget for senseBox selection
class _SenseBoxSelectionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final OpenSenseMapBloc osemBloc = Provider.of<OpenSenseMapBloc>(context);
    
    // Show the button only if the user is authenticated
    if (!osemBloc.isAuthenticated) {
      return const SizedBox
          .shrink(); // Return an empty widget if not authenticated
    }
  
    return IconButton.outlined(
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          side: BorderSide(
            color: osemBloc.selectedSenseBox == null
                ? Theme.of(context)
                    .colorScheme
                    .error // Red outline if no box is selected
                : Theme.of(context)
                    .colorScheme
                    .tertiary, // Default outline if a box is selected
            width: 2,
          ),
        ),
        onPressed: () => showSenseBoxSelection(context, osemBloc),
        icon: StreamBuilder<SenseBox?>(
          stream: osemBloc.senseBoxStream,
          initialData: osemBloc.selectedSenseBox,
          builder: (context, snapshot) {
            var selectedBox = snapshot.data;

            if (snapshot.hasError) {
              return Icon(Icons.error,
                  color: Theme.of(context).colorScheme.error);
            } else if (selectedBox == null) {
              // If no box is selected, show a red icon
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  '...',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ]);
            } else {
              // If a box is selected, show a green checkbox and the name of the box
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check,
                      color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Text(
                    truncateBoxName(selectedBox.name ?? ''),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary),
                  ),
                ],
              );
            }
          },
        ));
  }
}

// Widget for floating action buttons
class _FloatingButtons extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  const _FloatingButtons({required this.bleBloc, required this.recordingBloc});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: bleBloc.selectedDeviceNotifier,
      builder: (context, selectedDevice, child) {
        if (selectedDevice == null) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _ConnectButton(bleBloc: bleBloc),
              ),
              const SizedBox(width: 12),
              _SenseBoxSelectionButton(),
            ],
          );
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StartStopButton(recordingBloc: recordingBloc),
              _DisconnectButton(bleBloc: bleBloc),
              _SenseBoxSelectionButton(),
            ],
          );
        }
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
                  width: 200, // Set a fixed width for the button
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
                  width: 200, // Set a fixed width for the button
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isBluetoothEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerLow, // Disabled color
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
      // : recordingBloc.isRecording
      //     ? Colors.redAccent
      //     : Theme.of(context).colorScheme.primaryContainer,
      onPressed: () {
        recordingBloc.isRecording
            ? recordingBloc.stopRecording()
            : recordingBloc.startRecording();
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
              ? const Loader()
              : const Icon(Icons.bluetooth_disabled),
          label: isReconnecting
              ? Text(AppLocalizations.of(context)!.connectionButtonReconnecting)
              : Text(AppLocalizations.of(context)!.connectionButtonDisconnect),
          // backgroundColor: Theme.of(context).colorScheme.primary,
          onPressed: bleBloc.disconnectDevice,
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
