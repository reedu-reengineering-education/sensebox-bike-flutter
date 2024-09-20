import 'package:flutter_svg/svg.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login_selection_modal.dart';
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
    final osemBloc = Provider.of<OpenSenseMapBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/images/sensebox_bike_logo.svg',
          height: 32,
        ),

        // title: const Text('senseBox:bike'),
        // forceMaterialTransparency: true,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.person),
            onPressed: () => showLoginOrSenseBoxSelection(context, osemBloc),
            label: StreamBuilder<SenseBox?>(
              stream: osemBloc.senseBoxStream,
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
          ),
          // const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.route),
            label: const Text('Tracks'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TracksScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.only(bottom: 86),
          child: HomeScrollableScreen(sensorBloc: sensorBloc)), // room for FAB
      floatingActionButton: ValueListenableBuilder(
          valueListenable: bleBloc.selectedDeviceNotifier,
          builder: (context, selectedDevice, child) {
            if (selectedDevice == null) {
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
                        onPressed: () =>
                            showDeviceSelectionDialog(context, bleBloc),
                      );
                    }
                  });
            } else {
              return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      label: Text(recordingBloc.isRecording ? 'Stop' : 'Start'),
                      icon: Icon(recordingBloc.isRecording
                          ? Icons.stop
                          : Icons.fiber_manual_record),
                      backgroundColor: recordingBloc.isRecording
                          ? const Color.fromARGB(255, 255, 124, 124)
                          : Colors.greenAccent,
                      onPressed: () {
                        recordingBloc.isRecording
                            ? recordingBloc.stopRecording()
                            : recordingBloc.startRecording();
                      },
                    ),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: bleBloc.isReconnectingNotifier,
                      builder: (context, isReconnecting, child) {
                        return FloatingActionButton.extended(
                          // Show the CircularProgressIndicator instead of the icon during reconnection
                          icon: isReconnecting
                              ? const CircularProgressIndicator()
                              : const Icon(Icons
                                  .bluetooth_disabled), // Default icon when not reconnecting

                          label: isReconnecting
                              ? const Text('Reconnecting...')
                              : const Text('Disconnect'),

                          backgroundColor: Theme.of(context).primaryColorLight,

                          // Disconnect action
                          onPressed: bleBloc.disconnectDevice,
                        );
                      },
                    )
                  ]);
            }
          }),
    );
  }
}
