import 'dart:math';
import 'package:ble_app/blocs/ble_bloc.dart';
import 'package:ble_app/blocs/geolocation_bloc.dart';
import 'package:ble_app/blocs/sensor_bloc.dart';
import 'package:ble_app/providers/recording_state_provider.dart';
import 'package:ble_app/ui/widgets/ble_device_selection_dialog_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/geolocation_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bleBloc = Provider.of<BleBloc>(context);
    final recordingState = Provider.of<RecordingState>(context);
    final geolocationBloc = Provider.of<GeolocationBloc>(context);
    final sensorBloc = Provider.of<SensorBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('BLE & Geolocation Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => showDeviceSelectionDialog(context, bleBloc),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: MyScrollablePage(sensorBloc: sensorBloc),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (recordingState.isRecording) {
            recordingState.stopRecording();
            // Optionally, you might want to stop sensor data collection
          } else {
            recordingState.startRecording();
            // Optionally, you might want to start sensor data collection
          }
        },
        child: recordingState.isRecording
            ? const Icon(Icons.stop)
            : const Icon(Icons.play_arrow),
      ),
    );
  }
}

class MyScrollablePage extends StatelessWidget {
  final SensorBloc sensorBloc;

  MyScrollablePage({required this.sensorBloc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        clipBehavior: Clip.none,
        slivers: [
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              minHeight: 200.0,
              maxHeight: MediaQuery.of(context).size.height / 2,
              child: Card(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  child: GeolocationMapWidget(), // Directly use the map widget
                ),
                clipBehavior: Clip.hardEdge,
              ),
            ),
            pinned: true,
          ),
          SliverSafeArea(
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
