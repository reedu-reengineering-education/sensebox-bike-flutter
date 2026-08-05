import 'dart:math';
import 'package:sensebox_bike/ble/ble_characteristic_ref.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/geolocation_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_availability.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensebox.dart' hide Sensor;
import 'package:sensebox_bike/sensors/sensor.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/common/surface_outlined_icon_button.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/info_banner.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/layout/form_factor.dart';

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

    final mapStack = _MapStack(
      bleBloc: bleBloc,
      recordingBloc: recordingBloc,
      geolocationBloc: geolocationBloc,
    );

    return Scaffold(
      body: Column(
        children: [
          _HomeBanners(bleBloc: bleBloc, recordingBloc: recordingBloc),
          Expanded(
            child: _HomeScrollBody(
              bleBloc: bleBloc,
              sensorBloc: sensorBloc,
              mapStack: mapStack,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBanners extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;

  const _HomeBanners({
    required this.bleBloc,
    required this.recordingBloc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: bleBloc.connectionErrorNotifier,
          builder: (context, error, child) {
            if (error != true) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                const SizedBox(height: 48),
                _ConnectionErrorBanner(bleBloc: bleBloc),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
        ListenableBuilder(
          listenable: recordingBloc,
          builder: (context, _) {
            if (!recordingBloc.isRecording ||
                !recordingBloc.activeCollectionMode.usesPeriodicTimer) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 48, bottom: 8),
              child: InfoBanner(
                text: AppLocalizations.of(context)!
                    .recordingPeriodicCollectionMode(
                  recordingBloc.collectionIntervalSeconds,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MapStack extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final GeolocationBloc geolocationBloc;

  const _MapStack({
    required this.bleBloc,
    required this.recordingBloc,
    required this.geolocationBloc,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const GeolocationMapWidget(),
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
    );
  }
}

/// Phone + iPad: pinned map header with sensor grid scrolling below.
class _HomeScrollBody extends StatelessWidget {
  final BleBloc bleBloc;
  final SensorBloc sensorBloc;
  final Widget mapStack;

  const _HomeScrollBody({
    required this.bleBloc,
    required this.sensorBloc,
    required this.mapStack,
  });

  /// Height of one square sensor tile row (grid default aspect ratio is 1).
  double _oneSensorTileHeight(BuildContext context, double maxWidth) {
    const horizontalPadding = 16.0; // SliverSafeArea left + right
    const crossAxisSpacing = 8.0;
    final crossAxisCount = context.homeSensorCrossAxisCount();
    final tileExtent = (maxWidth -
            horizontalPadding -
            crossAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
    return tileExtent + 8; // one row + bottom padding
  }

  @override
  Widget build(BuildContext context) {
    // Phone: unchanged screen-fraction header heights.
    if (!context.isTablet) {
      return CustomScrollView(
        clipBehavior: Clip.none,
        slivers: [
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              minHeight:
                  context.homeMapMinHeight(isConnected: bleBloc.isConnected),
              maxHeight:
                  context.homeMapMaxHeight(isConnected: bleBloc.isConnected),
              child: mapStack,
            ),
            pinned: true,
          ),
          SliverSafeArea(
            minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            sliver: _SensorSliver(bleBloc: bleBloc, sensorBloc: sensorBloc),
          ),
        ],
      );
    }

    // iPad: same vertical scroll as phone. When connected, map leaves room for
    // exactly one sensor tile row; scroll to reveal the rest.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final connected = bleBloc.isConnected;
        final sensorPeek = _oneSensorTileHeight(context, constraints.maxWidth);

        final double minHeight;
        final double maxHeight;
        if (!connected) {
          minHeight = available;
          maxHeight = available;
        } else {
          maxHeight = max(available - sensorPeek, available * 0.4);
          minHeight = min(available * 0.33, maxHeight);
        }

        return CustomScrollView(
          clipBehavior: Clip.none,
          slivers: [
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                minHeight: minHeight,
                maxHeight: maxHeight,
                child: mapStack,
              ),
              pinned: true,
            ),
            SliverSafeArea(
              minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              sliver: _SensorSliver(bleBloc: bleBloc, sensorBloc: sensorBloc),
            ),
          ],
        );
      },
    );
  }
}

class _SensorSliver extends StatelessWidget {
  final BleBloc bleBloc;
  final SensorBloc sensorBloc;

  const _SensorSliver({
    required this.bleBloc,
    required this.sensorBloc,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleDevice?>(
      valueListenable: bleBloc.selectedDeviceNotifier,
      builder: (context, device, child) {
        if (device == null || bleBloc.connectionErrorNotifier.value) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return ValueListenableBuilder<List<BleCharacteristicRef>>(
          valueListenable: bleBloc.availableCharacteristics,
          builder: (context, characteristics, child) {
            return ValueListenableBuilder<int>(
              valueListenable:
                  bleBloc.characteristicStreams.livePayloadVersion,
              builder: (context, _, child) {
                if (sensorBloc.availableSensors.isEmpty) {
                  if (characteristics.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: SizedBox.shrink(),
                    );
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.generalLoading,
                        ),
                      ),
                    ),
                  );
                }

                return _SensorGrid(
                  sensors: sensorBloc.availableSensors,
                );
              },
            );
          },
        );
      },
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

// Widget for senseBox selection as a badge-like button
class _SenseBoxSelectionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<OpenSenseMapBloc>(
      builder: (context, osemBloc, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        // Always show the button, but with different styling based on authentication
        final bool isAuthenticated = osemBloc.isAuthenticated;
        final bool isAuthenticating = osemBloc.isAuthenticating;

        return StreamBuilder<SenseBox?>(
          stream: osemBloc.senseBoxStream,
          initialData: osemBloc.selectedSenseBox,
          builder: (context, snapshot) {
            final selectedBox = snapshot.data;
            final bool hasError = snapshot.hasError;
            final bool noBox = selectedBox == null;

            // Different styling for authenticated vs unauthenticated state
            Color backgroundColor;
            Color textColor;
            Color borderColor;
            IconData icon;
            String label;
            VoidCallback? onTap;

            if (isAuthenticating) {
              // Loading state - disabled button with loading indicator
              backgroundColor = colorScheme.surface.withValues(alpha: 0.5);
              textColor = colorScheme.onSurface.withValues(alpha: 0.6);
              borderColor = colorScheme.outline.withValues(alpha: 0.3);
              icon = Icons.hourglass_empty;
              label = AppLocalizations.of(context)!.generalLoading;
              onTap = null; // Disable button
            } else if (!isAuthenticated) {
              // Unauthenticated state - use theme-defined dark red with white text
              backgroundColor = loginRequiredColor;
              textColor = loginRequiredTextColor;
              borderColor = loginRequiredColor;
              icon = Icons.login;
              label = AppLocalizations.of(context)!.loginRequiredMessage;
              onTap = () {
                // Navigate to settings page when not authenticated
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()));
              };
            } else {
              // Authenticated state - use existing logic
              textColor = hasError
                  ? colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onTertiaryContainer;
              backgroundColor = hasError
                  ? colorScheme.errorContainer
                  : Theme.of(context).colorScheme.tertiary;
              borderColor = hasError
                  ? colorScheme.outlineVariant
                  : Theme.of(context).colorScheme.tertiary;
              icon = hasError
                  ? Icons.error
                  : noBox
                      ? Icons.add_box_outlined
                      : Icons.emergency_share_rounded;
              label = hasError
                  ? AppLocalizations.of(context)!.generalError
                  : noBox
                      ? AppLocalizations.of(context)!.selectOrCreateBox
                      : selectedBox.name ?? '';
              final configBloc = Provider.of<ConfigurationBloc>(context, listen: false);
              onTap = () => showSenseBoxSelection(context, osemBloc, configBloc);
            }

            return InkWell(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(borderRadiusSmall),
                  border: Border.all(
                    color: borderColor,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon in a small circle background
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Center(
                        child: isAuthenticating
                            ? Loader(light: true)
                            : Icon(
                                icon,
                                color: textColor,
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
                            height: 1.2),
                        maxLines: 3,
                      ),
                    ),
                    // Optional description (for error or noBox) - only show when authenticated and not loading
                    if (isAuthenticated && !isAuthenticating)
                      if (hasError)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child:
                              Icon(Icons.refresh, color: textColor, size: 16),
                        )
                      else if (noBox)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.arrow_forward,
                              color: textColor, size: 16),
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        bleBloc.isConnectingNotifier,
        bleBloc.isReconnectingNotifier,
        bleBloc.selectedDeviceNotifier,
        recordingBloc,
      ]),
      builder: (context, _) {
        final isConnecting = bleBloc.isConnectingNotifier.value;
        final isReconnecting = bleBloc.isReconnectingNotifier.value;
        final selectedDevice = bleBloc.selectedDeviceNotifier.value;
        final buttonsBusy = isConnecting || isReconnecting;

        if (selectedDevice == null && !isReconnecting) {
          return Column(
            spacing: 12,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ConnectButton(bleBloc: bleBloc, isConnecting: isConnecting),
              _SenseBoxSelectionButton(),
            ],
          );
        }

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
                    buttonsBusy: buttonsBusy,
                  ),
                ),
                Expanded(
                  child: _DisconnectButton(
                    bleBloc: bleBloc,
                    recordingBloc: recordingBloc,
                    buttonsBusy: buttonsBusy,
                    isReconnecting: isReconnecting,
                  ),
                ),
              ],
            ),
            if (recordingBloc.isRecording &&
                recordingBloc.activeCollectionMode.showsManualSampleButton)
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
            _SenseBoxSelectionButton(),
          ],
        );
      },
    );
  }
}

// Connect button
class _ConnectButton extends StatelessWidget {
  final BleBloc bleBloc;
  final bool isConnecting;
  const _ConnectButton({
    required this.bleBloc,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnecting) {
      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            label: Text(
              AppLocalizations.of(context)!.connectionButtonConnecting,
            ),
            icon: const Loader(),
            onPressed: null,
          ),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: bleBloc.isBluetoothEnabledNotifier,
      builder: (context, isBluetoothEnabled, child) {
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isBluetoothEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
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
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              icon: Icon(
                Icons.bluetooth,
                color: isBluetoothEnabled
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                if (isBluetoothEnabled) {
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
      },
    );
  }
}

// Start/Stop button
class _StartStopButton extends StatelessWidget {
  final RecordingBloc recordingBloc;
  final bool buttonsBusy;
  const _StartStopButton({
    required this.recordingBloc,
    required this.buttonsBusy,
  });

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
      onPressed: buttonsBusy
          ? null
          : () async {
              if (recordingBloc.isRecording) {
                await recordingBloc.stopRecording();
              } else {
                await recordingBloc.startRecording();
              }
            },
    );
  }
}

class _DisconnectButton extends StatelessWidget {
  final BleBloc bleBloc;
  final RecordingBloc recordingBloc;
  final bool buttonsBusy;
  final bool isReconnecting;
  const _DisconnectButton({
    required this.bleBloc,
    required this.recordingBloc,
    required this.buttonsBusy,
    required this.isReconnecting,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceOutlinedIconButton(
      icon: isReconnecting
          ? Icons.bluetooth_searching
          : Icons.bluetooth_disabled,
      label: isReconnecting
          ? AppLocalizations.of(context)!.connectionButtonReconnecting
          : AppLocalizations.of(context)!.connectionButtonDisconnect,
      onPressed: buttonsBusy
          ? null
          : () async {
              if (recordingBloc.isRecording) {
                await recordingBloc.stopRecording();
              }
              await bleBloc.disconnectDevice(
                  reason: BleDisconnectReason.userRequested);
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
  final List<Sensor> sensors;
  const _SensorGrid({required this.sensors});

  @override
  Widget build(BuildContext context) {
    final sortedSensors = sortSensorsByUiPriority(sensors);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.homeSensorCrossAxisCount(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return sortedSensors[index].buildWidget();
        },
        childCount: sortedSensors.length,
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
