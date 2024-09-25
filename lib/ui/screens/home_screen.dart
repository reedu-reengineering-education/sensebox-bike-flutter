import 'dart:math';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';

// HomeScreen now delegates sections to smaller widgets
class HomeScreen extends StatelessWidget {
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
                  Positioned(
                    top: 0,
                    right: 8,
                    child: SafeArea(
                      child: _SenseBoxLoginButton(),
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

// Widget for login or senseBox selection
class _SenseBoxLoginButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final OpenSenseMapBloc osemBloc = Provider.of<OpenSenseMapBloc>(context);

    return FilledButton.icon(
      onPressed: () => showLoginOrSenseBoxSelection(context, osemBloc),
      label: StreamBuilder<SenseBox?>(
        stream: osemBloc.senseBoxStream,
        initialData: osemBloc.selectedSenseBox,
        builder: (context, snapshot) {
          if (!osemBloc.isAuthenticated) {
            return const Text('Login');
          } else if (snapshot.hasError) {
            return const Text('Error');
          } else {
            return Text(snapshot.data?.name ?? 'No senseBox');
          }
        },
      ),
      icon: const Icon(Icons.person),
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
    return ValueListenableBuilder(
      valueListenable: bleBloc.selectedDeviceNotifier,
      builder: (context, selectedDevice, child) {
        if (selectedDevice == null) {
          return _ConnectButton(bleBloc: bleBloc);
        } else {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StartStopButton(recordingBloc: recordingBloc),
              const SizedBox(width: 12),
              _DisconnectButton(bleBloc: bleBloc),
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
        if (isConnecting) {
          return const FloatingActionButton.extended(
            label: Text('Connecting...'),
            icon: CircularProgressIndicator(),
            onPressed: null,
          );
        } else {
          return FloatingActionButton.extended(
            label: const Text('Connect'),
            icon: const Icon(Icons.bluetooth),
            onPressed: () => showDeviceSelectionDialog(context, bleBloc),
          );
        }
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
    return FloatingActionButton.extended(
      label: Text(recordingBloc.isRecording ? 'Stop' : 'Start'),
      icon: Icon(
          recordingBloc.isRecording ? Icons.stop : Icons.fiber_manual_record),
      backgroundColor: recordingBloc.isRecording
          ? Colors.redAccent
          : Theme.of(context).colorScheme.primaryContainer,
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
        return FloatingActionButton.extended(
          icon: isReconnecting
              ? const CircularProgressIndicator()
              : const Icon(Icons.bluetooth_disabled),
          label: isReconnecting
              ? const Text('Reconnecting...')
              : const Text('Disconnect'),
          backgroundColor: Theme.of(context).secondaryHeaderColor,
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
