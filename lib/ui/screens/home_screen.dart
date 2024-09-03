import 'dart:math';
import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/sensor_bloc.dart';
import 'package:ble_app/blocs/recording_bloc.dart';
import 'package:ble_app/ui/widgets/ble_device_selection_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/geolocation_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleBloc = Provider.of<BleBloc>(context);
    final recordingBloc = Provider.of<RecordingBloc>(context);
    final sensorBloc = Provider.of<SensorBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('senseBox:bike'),
        forceMaterialTransparency: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: HomeScrollableScreen(sensorBloc: sensorBloc),
      ),
      floatingActionButton: ValueListenableBuilder(
          valueListenable: bleBloc.selectedDeviceNotifier,
          builder: (context, selectedDevice, child) {
            if (selectedDevice == null) {
              return FloatingActionButton.extended(
                label: const Text('Connect'),
                icon: const Icon(Icons.bluetooth),
                onPressed: () => showDeviceSelectionDialog(context, bleBloc),
              );
            } else {
              return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        onPressed: bleBloc.disconnectDevice,
                        child: const Icon(Icons.bluetooth_disabled)),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      label: Text(recordingBloc.isRecording
                          ? 'Stop recording'
                          : 'Start recording'),
                      icon: Icon(recordingBloc.isRecording
                          ? Icons.stop
                          : Icons.fiber_manual_record),
                      onPressed: () {
                        recordingBloc.toggleRecording();
                      },
                    )
                  ]);
            }
          }),
    );
  }
}

class HomeScrollableScreen extends StatelessWidget {
  final SensorBloc sensorBloc;

  const HomeScrollableScreen({super.key, required this.sensorBloc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        clipBehavior: Clip.none,
        slivers: [
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              minHeight: 200.0,
              maxHeight: MediaQuery.of(context).size.height / 3,
              child: const Card(
                elevation: 0,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: double.infinity,
                  child: GeolocationMapWidget(), // Directly use the map widget
                ),
              ),
            ),
            pinned: true,
          ),
          SliverSafeArea(
            minimum: const EdgeInsets.fromLTRB(4, 24, 4, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns
                crossAxisSpacing: 8, // Spacing between columns
                mainAxisSpacing: 8, // Spacing between rows
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final widgets = sensorBloc.getSensorWidgets();
                  return index < widgets.length ? widgets[index] : null;
                },
                childCount: sensorBloc.getSensorWidgets().length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
