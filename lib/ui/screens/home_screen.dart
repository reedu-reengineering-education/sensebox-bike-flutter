import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sensebox_bike/app/app_router.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/configuration_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection_modal.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/error_banner.dart';
import 'package:sensebox_bike/ui/widgets/sensor/sensor_widget_factory.dart';

// HomeScreen now delegates sections to smaller widgets
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordingBloc, RecordingState>(
      listenWhen: (previous, current) =>
          previous.pendingBatchUploadRequest?.createdAt !=
          current.pendingBatchUploadRequest?.createdAt,
      listener: (context, state) {
        final request = state.pendingBatchUploadRequest;
        if (request == null) {
          return;
        }

        final recordingBloc = context.read<RecordingBloc>();
        final batchUploadService = recordingBloc.batchUploadService;
        recordingBloc.clearBatchUploadRequest();

        if (batchUploadService == null) {
          return;
        }

        UploadProgressOverlay.show(
          context,
          batchUploadService: batchUploadService,
          canUpload: request.canUpload,
          onUploadComplete: recordingBloc.onBatchUploadCompleted,
          onUploadFailed: recordingBloc.onBatchUploadFailed,
          onStartUpload: () {
            if (request.canUpload) {
              recordingBloc.startBatchUpload(request.track, request.senseBox);
            }
          },
        );
      },
      child: BlocBuilder<BleBloc, BleState>(
        buildWhen: (previous, current) =>
            previous.isConnected != current.isConnected ||
            previous.selectedDevice != current.selectedDevice ||
            previous.connectionError != current.connectionError,
        builder: (context, bleState) {
          final bleBloc = context.read<BleBloc>();
          final recordingBloc = context.read<RecordingBloc>();
          final sensorBloc = context.read<SensorBloc>();
          return Scaffold(
            body: Column(
              children: [
                // Error banner with spacing
                if (bleState.connectionError)
                  Column(
                    children: [
                      const SizedBox(height: 48),
                      _ConnectionErrorBanner(bleBloc: bleBloc),
                      const SizedBox(height: 16),
                    ],
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
                              (bleState.isConnected ? 0.65 : 0.85),
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
                                      bleBloc: bleBloc,
                                      recordingBloc: recordingBloc),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pinned: true,
                      ),
                      SliverSafeArea(
                        minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        sliver: BlocBuilder<SensorBloc, SensorState>(
                          builder: (context, _) {
                            final device = bleState.selectedDevice;
                            // Only show sensor area if device is connected and not in error state
                            if (device == null || bleState.connectionError) {
                              return SliverToBoxAdapter(
                                  child: SizedBox.shrink());
                            }

                            // Check if there are actually any sensor widgets available
                            final widgets = buildAvailableSensorWidgets(
                              sensors: sensorBloc.sensors,
                              availableCharacteristicUuids: bleState
                                  .availableCharacteristics
                                  .map((e) => e.uuid.toString())
                                  .toSet(),
                            );
                            if (widgets.isEmpty) {
                              // Connected but no sensor data available: show nothing
                              return SliverToBoxAdapter(
                                  child: SizedBox.shrink());
                            }

                            // Connected and has sensor data: show sensor grid
                            return _SensorGrid(widgets: widgets);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
    return ErrorBanner(
      errorText: AppLocalizations.of(context)!.errorBleConnectionFailed,
      onDismiss: () => bleBloc.resetConnectionError(),
    );
  }
}

// Widget for senseBox selection as a badge-like button
class _SenseBoxSelectionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OpenSenseMapBloc, OpenSenseMapState>(
      builder: (context, osemState) {
        final osemBloc = context.read<OpenSenseMapBloc>();
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        // Always show the button, but with different styling based on authentication
        final isAuthenticated = osemState.isAuthenticated;
        final isAuthenticating = osemState.isAuthenticating;
        final selectedBox = osemState.selectedSenseBox;
        final noBox = selectedBox == null;

        Color backgroundColor;
        Color textColor;
        Color borderColor;
        IconData icon;
        String label;
        VoidCallback? onTap;

        if (isAuthenticating) {
          backgroundColor = colorScheme.surface.withValues(alpha: 0.5);
          textColor = colorScheme.onSurface.withValues(alpha: 0.6);
          borderColor = colorScheme.outline.withValues(alpha: 0.3);
          icon = Icons.hourglass_empty;
          label = AppLocalizations.of(context)!.generalLoading;
          onTap = null;
        } else if (!isAuthenticated) {
          backgroundColor = loginRequiredColor;
          textColor = loginRequiredTextColor;
          borderColor = loginRequiredColor;
          icon = Icons.login;
          label = AppLocalizations.of(context)!.loginRequiredMessage;
          onTap = () {
            context.go(AppRoutes.settings);
          };
        } else {
          textColor = Theme.of(context).colorScheme.onTertiaryContainer;
          backgroundColor = Theme.of(context).colorScheme.tertiary;
          borderColor = Theme.of(context).colorScheme.tertiary;
          icon = noBox ? Icons.add_box_outlined : Icons.emergency_share_rounded;
          label = noBox
              ? AppLocalizations.of(context)!.selectOrCreateBox
              : selectedBox.name ?? '';
          final configBloc = context.read<ConfigurationBloc>();
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                if (isAuthenticated && !isAuthenticating && noBox)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child:
                        Icon(Icons.arrow_forward, color: textColor, size: 16),
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
    return BlocBuilder<BleBloc, BleState>(
      builder: (context, bleState) {
        final isReconnecting = bleState.isReconnecting;
        final selectedDevice = bleState.selectedDevice;
        // Show buttons if device is connected or if reconnecting
        if (selectedDevice == null && !isReconnecting) {
          return Column(
            spacing: 12,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ConnectButton(bleBloc: bleBloc),
              // Always show sensebox selection button with different styling based on auth state
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
              // Always show sensebox selection button with different styling based on auth state
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
    return BlocBuilder<BleBloc, BleState>(
      builder: (context, bleState) {
        final isConnecting = bleState.isConnecting;
        final isBluetoothEnabled = bleState.isBluetoothEnabled;
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
    return BlocBuilder<RecordingBloc, RecordingState>(
      builder: (context, recordingState) {
        return FilledButton.icon(
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          label: Text(recordingState.isRecording
              ? AppLocalizations.of(context)!.connectionButtonStop
              : AppLocalizations.of(context)!.connectionButtonStart),
          icon: Icon(recordingState.isRecording
              ? Icons.stop
              : Icons.fiber_manual_record),
          onPressed: isReconnecting
              ? null
              : () async {
                  if (recordingState.isRecording) {
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
    return BlocBuilder<BleBloc, BleState>(
      builder: (context, bleState) {
        final isReconnecting = bleState.isReconnecting;
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
  final List<Widget> widgets;
  const _SensorGrid({required this.widgets});

  @override
  Widget build(BuildContext context) {
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
