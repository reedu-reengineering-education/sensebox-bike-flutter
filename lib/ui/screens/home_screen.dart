import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_device_selection_dialog_widget.dart';
import 'package:sensebox_bike/ui/widgets/home/home_scrollable_screen_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        // forceMaterialTransparency: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TracksScreen()),
            ),
          ),
        ],
      ),
      body: HomeScrollableScreen(sensorBloc: sensorBloc),
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
                        backgroundColor: Theme.of(context).primaryColorLight,
                        onPressed: bleBloc.disconnectDevice,
                        child: const Icon(Icons.bluetooth_disabled)),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      label: Text(recordingBloc.isRecording ? 'Stop' : 'Start'),
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
