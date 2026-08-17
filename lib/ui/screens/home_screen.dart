import 'dart:math';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/sensebox_selection_button.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';
import 'package:sensebox_bike/ui/widgets/common/info_banner.dart';

// HomeScreen now delegates sections to smaller widgets
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BleBloc bleBloc = Provider.of<BleBloc>(context);
    final RecordingBloc recordingBloc = Provider.of<RecordingBloc>(context);
    final SensorBloc sensorBloc = Provider.of<SensorBloc>(context);
    final GeolocationBloc geolocationBloc =
        Provider.of<GeolocationBloc>(context);

    recordingBloc.setContext(context);

    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.connectionErrorNotifier,
      builder: (context, connectionError, _) {
        if (context.useSideRail) {
          return _TabletLayout(
            bleBloc: bleBloc,
            recordingBloc: recordingBloc,
            sensorBloc: sensorBloc,
            geolocationBloc: geolocationBloc,
            connectionError: connectionError,
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // Error banner with spacing
              if (connectionError)
                Column(
                  children: [
                    const SizedBox(height: 48),
                    _ConnectionErrorBanner(bleBloc: bleBloc),
                    const SizedBox(height: 16),
                  ],
                ),
              _PeriodicModeBanner(
                recordingBloc: recordingBloc,
                padding: const EdgeInsets.only(top: 48, bottom: 8),
              ),
              // Main content
              Expanded(
                child: CustomScrollView(
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
                            // Top fade softens the map under the status bar on
                            // phones. On a tablet there is enough map showing
                            // that it just reads as a stray band.
                            if (!context.isTablet)
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _BottomGradient(
                                  direction: AxisDirection.up,
                                ),
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
                                  bleBloc: bleBloc,
                                  recordingBloc: recordingBloc,
                                  geolocationBloc: geolocationBloc,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pinned: true,
                    ),
                    SliverSafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      sliver: _SensorWidgets(
                        bleBloc: bleBloc,
                        sensorBloc: sensorBloc,
                        connectionError: connectionError,
                        empty:
                            const SliverToBoxAdapter(child: SizedBox.shrink()),
                        loading: const SliverToBoxAdapter(
                          child: _SensorLoadingMessage(),
                        ),
                        builder: (context, widgets) =>
                            _SensorGrid(widgets: widgets),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Resolves the sensors that currently have data available and returns their
/// widgets, sorted by [Sensor.uiPriority].
List<Widget> _buildAvailableSensorWidgets({
  required List<Sensor> sensors,
  required Set<String> availableCharacteristicUuids,
}) {
  final availableSensors = sensors.where((sensor) {
    if (FeatureFlags.hideSurfaceAnomalySensor &&
        sensor.title == 'surface_anomaly') {
      return false;
    }
    return availableCharacteristicUuids.contains(sensor.characteristicUuid);
  }).toList();

  availableSensors.sort((a, b) => a.uiPriority.compareTo(b.uiPriority));
  return availableSensors.map((sensor) => sensor.buildWidget()).toList();
}

/// Placeholder while the box is connected but no sensor has reported yet.
class _SensorLoadingMessage extends StatelessWidget {
  const _SensorLoadingMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(AppLocalizations.of(context)!.generalLoading),
      ),
    );
  }
}

/// Shown while recording in periodic mode, naming the sampling interval.
class _PeriodicModeBanner extends StatelessWidget {
  final RecordingBloc recordingBloc;
  final EdgeInsets padding;

  const _PeriodicModeBanner({
    required this.recordingBloc,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: recordingBloc,
      builder: (context, _) {
        if (!recordingBloc.isRecording ||
            !recordingBloc.activeCollectionMode.usesPeriodicTimer) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: padding,
          child: InfoBanner(
            text: AppLocalizations.of(context)!.recordingPeriodicCollectionMode(
              recordingBloc.collectionIntervalSeconds,
            ),
          ),
        );
      },
    );
  }
}

/// Resolves the sensor tiles that are currently available and hands them to
/// [builder]. Renders [empty] while disconnected, in error, or with no tiles.
class _SensorWidgets extends StatelessWidget {
  final BleBloc bleBloc;
  final SensorBloc sensorBloc;
  final bool connectionError;
  final Widget empty;

  /// Shown once the box advertises characteristics but no tile has data yet.
  final Widget loading;
  final Widget Function(BuildContext context, List<Widget> widgets) builder;

  const _SensorWidgets({
    required this.bleBloc,
    required this.sensorBloc,
    required this.connectionError,
    required this.empty,
    required this.loading,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleDevice?>(
      valueListenable: bleBloc.selectedDeviceNotifier,
      builder: (context, device, _) {
        // Only show sensor area if device is connected and not in error state
        if (device == null || connectionError) {
          return empty;
        }

        return ValueListenableBuilder<List<BleCharacteristicRef>>(
          valueListenable: bleBloc.availableCharacteristics,
          builder: (context, characteristics, _) {
            // Live payloads can arrive after the characteristic list, so
            // rebuild on those too rather than sitting on an empty grid.
            return ValueListenableBuilder<int>(
              valueListenable: bleBloc.characteristicStreams.livePayloadVersion,
              builder: (context, _, __) {
                // Check if there are actually any sensor widgets available
                final widgets = _buildAvailableSensorWidgets(
                  sensors: sensorBloc.sensors,
                  availableCharacteristicUuids:
                      characteristics.map((e) => e.uuidString).toSet(),
                );
                if (widgets.isEmpty) {
                  // Characteristics are known but no tile has data yet, so the
                  // box is still warming up; otherwise show nothing at all.
                  return characteristics.isEmpty ? empty : loading;
                }

                return builder(context, widgets);
              },
            );
          },
        );
      },
    );
  }
}

/// Tablet landscape layout: full-bleed map with a floating rail on the right
/// holding the sensor grid on top and the connect / senseBox actions below.
class _TabletLayout extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final SensorBloc sensorBloc;
  final GeolocationBloc geolocationBloc;
  final bool connectionError;

  const _TabletLayout({
    required this.bleBloc,
    required this.recordingBloc,
    required this.sensorBloc,
    required this.geolocationBloc,
    required this.connectionError,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GeolocationMapWidget()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (connectionError) _ConnectionErrorBanner(bleBloc: bleBloc),
                  _PeriodicModeBanner(
                    recordingBloc: recordingBloc,
                    padding: EdgeInsets.only(top: connectionError ? 8 : 0),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: context.sideRailWidth,
                  child: _SideRail(
                    bleBloc: bleBloc,
                    recordingBloc: recordingBloc,
                    sensorBloc: sensorBloc,
                    geolocationBloc: geolocationBloc,
                    connectionError: connectionError,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating rail itself. Sizes to its content so it only covers the map
/// where it has something to show.
class _SideRail extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final SensorBloc sensorBloc;
  final GeolocationBloc geolocationBloc;
  final bool connectionError;

  const _SideRail({
    required this.bleBloc,
    required this.recordingBloc,
    required this.sensorBloc,
    required this.geolocationBloc,
    required this.connectionError,
  });

  @override
  Widget build(BuildContext context) {
    return _FloatingCard(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sensor grid on top, scrolls when it outgrows the rail.
          Flexible(
            child: _SensorWidgets(
              bleBloc: bleBloc,
              sensorBloc: sensorBloc,
              connectionError: connectionError,
              empty: const SizedBox.shrink(),
              loading: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _SensorLoadingMessage(),
              ),
              builder: (context, widgets) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GridView.extent(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  maxCrossAxisExtent: kSensorTileMaxExtent,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: widgets,
                ),
              ),
            ),
          ),
          // Actions pinned to the bottom of the rail.
          _ActionButtons(
            bleBloc: bleBloc,
            recordingBloc: recordingBloc,
            geolocationBloc: geolocationBloc,
          ),
        ],
      ),
    );
  }
}

// Connection error banner widget
class _ConnectionErrorBanner extends StatelessWidget {
  final BleBloc bleBloc;

  const _ConnectionErrorBanner({required this.bleBloc});

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      text: AppLocalizations.of(context)!.errorBleConnectionFailed,
      color: Theme.of(context).colorScheme.info,
      onDismiss: () => bleBloc.resetConnectionError(),
    );
  }
}

// Widget for floating action buttons
class _FloatingButtons extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final GeolocationBloc geolocationBloc;
  const _FloatingButtons({
    required this.bleBloc,
    required this.recordingBloc,
    required this.geolocationBloc,
  });

  @override
  Widget build(BuildContext context) {
    return _FloatingCard(
      child: _ActionButtons(
        bleBloc: bleBloc,
        recordingBloc: recordingBloc,
        geolocationBloc: geolocationBloc,
      ),
    );
  }
}

/// Rounded surface used for the floating map controls and the tablet rail.
class _FloatingCard extends StatelessWidget {
  final Widget child;

  /// Defaults to the same surface the sensor cards use. The tablet rail passes
  /// the page background instead so the cards inside it stay distinguishable.
  final Color? color;

  const _FloatingCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }
}

// Connect / record / senseBox actions, without any surrounding chrome.
class _ActionButtons extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final GeolocationBloc geolocationBloc;
  const _ActionButtons({
    required this.bleBloc,
    required this.recordingBloc,
    required this.geolocationBloc,
  });

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context, listen: false);
    return ListenableBuilder(
      listenable: Listenable.merge([
        bleBloc.isConnectingNotifier,
        bleBloc.isReconnectingNotifier,
        bleBloc.selectedDeviceNotifier,
        recordingBloc,
        settingsBloc,
      ]),
      builder: (context, _) {
        final isConnecting = bleBloc.isConnectingNotifier.value;
        final isReconnecting = bleBloc.isReconnectingNotifier.value;
        final selectedDevice = bleBloc.selectedDeviceNotifier.value;
        final buttonsBusy = isConnecting || isReconnecting;
        // Show buttons if device is connected or if reconnecting
        if (selectedDevice == null && !isReconnecting) {
          return Column(
            spacing: 12,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ConnectButton(bleBloc: bleBloc),
              // Always show sensebox selection button with different styling based on auth state
              const SenseBoxSelectionButton(),
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
                    child: _StartStopButton(
                        recordingBloc: recordingBloc,
                        isReconnecting: isReconnecting),
                  ),
                  Expanded(
                    child: _DisconnectButton(
                        bleBloc: bleBloc, recordingBloc: recordingBloc),
                  ),
                ],
              ),
              if (recordingBloc.isRecording &&
                  settingsBloc.dataCollectionMode.showsManualSampleButton)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: const ButtonStyle(
                      padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    onPressed: buttonsBusy
                        ? null
                        : () => geolocationBloc.captureSample(),
                    icon: const Icon(Icons.add_location_alt),
                    label: Text(
                      AppLocalizations.of(context)!.recordingSaveSample,
                    ),
                  ),
                ),
              // Always show sensebox selection button with different styling based on auth state
              const SenseBoxSelectionButton(),
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        bleBloc.isConnectingNotifier,
        bleBloc.isBluetoothEnabledNotifier,
      ]),
      builder: (context, _) {
        final isConnecting = bleBloc.isConnectingNotifier.value;
        final isBluetoothEnabled = bleBloc.isBluetoothEnabledNotifier.value;
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
                      ? AppLocalizations.of(context)!.connectionButtonConnect
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
  }
}

// Start/Stop button
class _StartStopButton extends StatelessWidget {
  final RecordingBloc recordingBloc;
  final bool isReconnecting;
  const _StartStopButton(
      {required this.recordingBloc, required this.isReconnecting});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: recordingBloc.isRecordingNotifier,
      builder: (context, isRecording, _) {
        return FilledButton.icon(
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          label: Text(isRecording
              ? AppLocalizations.of(context)!.connectionButtonStop
              : AppLocalizations.of(context)!.connectionButtonStart),
          icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record),
          onPressed: isReconnecting
              ? null
              : () async {
                  if (isRecording) {
                    await recordingBloc.stopRecording();
                  } else {
                    await recordingBloc.startRecording();
                  }
                },
        );
      },
    );
  }
}

// Disconnect button
class _DisconnectButton extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  const _DisconnectButton({required this.bleBloc, required this.recordingBloc});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.isReconnectingNotifier,
      builder: (context, isReconnecting, _) {
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
          onPressed: isReconnecting
              ? null
              : () async {
                  // Stop recording if active before disconnecting
                  if (recordingBloc.isRecording) {
                    await recordingBloc.stopRecording();
                  }
                  bleBloc.disconnectDevice();
                },
        );
      },
    );
  }
}

// Bottom gradient widget
class _BottomGradient extends StatelessWidget {
  final AxisDirection direction;
  final double height;
  const _BottomGradient(
      {this.direction = AxisDirection.down, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: direction == AxisDirection.down
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            end: direction == AxisDirection.down
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        height: height,
      ),
    );
  }
}

/// Largest a sensor tile is allowed to get. Sized so phones stay at 2 columns
/// and an iPad in portrait lands on 4.
const double kSensorTileMaxExtent = 220;

// Widget for the sensor grid
class _SensorGrid extends StatelessWidget {
  final List<Widget> widgets;
  const _SensorGrid({required this.widgets});

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      // Column count follows the available width instead of being fixed, so
      // tiles keep roughly their phone size on wider screens (2-up on phones,
      // 4-up on an iPad in portrait) rather than stretching.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: kSensorTileMaxExtent,
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
