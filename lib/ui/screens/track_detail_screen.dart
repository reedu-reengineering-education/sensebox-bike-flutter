import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:share_plus/share_plus.dart';

class TrackDetailScreen extends StatefulWidget {
  final int id;

  const TrackDetailScreen({super.key, required this.id});

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState(id);
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  late Future<TrackData?> _trackFuture;
  late Future<List<SensorData>> _sensorDataFuture;

  final int id;

  late String _sensorType;

  _TrackDetailScreenState(this.id);

  @override
  void initState() {
    super.initState();

    _sensorType = 'temperature'; // Default sensor type

    // Initialize the future in initState to avoid re-fetching data unnecessarily
    _trackFuture = IsarService().trackService.getTrackById(id);
    _sensorDataFuture = IsarService().sensorService.getSensorDataByTrackId(id);
  }

  List<String> getSensorTitles(List<SensorData> sensorData) {
    return sensorData.map((e) => e.title).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track $id'),
        actions: [
          IconButton(
            onPressed: () async {
              // Implement a way to export the track data to a CSV file
              final isarService = IsarService();
              final csvFilePath = await isarService.exportTrackToCsv(id);
              print('CSV file saved at: $csvFilePath');
              await Share.shareXFiles([XFile(csvFilePath)],
                  text: 'Here is the CSV export of your track data.');
            },
            icon: const Icon(Icons.file_download),
          ),
        ],
      ),
      body: FutureBuilder<TrackData?>(
        future: _trackFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While the future is loading, show a loading indicator
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            // If the future completed with an error, show an error message
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData) {
            // If the future completed but returned no data, show a message
            return const Text('No track available.');
          } else {
            // If the future completed with data, display the list
            TrackData track = snapshot.data!;

            return Stack(
              children: [
                Positioned.fill(
                  // This will make TrajectoryWidget fill the entire Stack
                  child: TrajectoryWidget(
                    geolocationData: track.geolocations.toList(),
                    sensorType: _sensorType,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: SafeArea(
                    child: Card.filled(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FutureBuilder<List<SensorData>>(
                          future: _sensorDataFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              // While the future is loading, show a loading indicator
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (snapshot.hasError) {
                              // If the future completed with an error, show an error message
                              return Text('Error: ${snapshot.error}');
                            } else if (!snapshot.hasData ||
                                snapshot.data!.isEmpty) {
                              // If the future completed but returned no data, show a message
                              return const Text('No sensor data available.');
                            } else {
                              // If the future completed with data, display the list
                              List<SensorData> sensorData = snapshot.data!;
                              List<String> sensorTitles =
                                  getSensorTitles(sensorData);
                              return SizedBox(
                                  // Set a fixed height for the horizontal ListView
                                  height: 50, // Adjust this height as needed
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    scrollDirection: Axis.horizontal,
                                    itemCount: sensorTitles.length,
                                    itemBuilder: (context, index) {
                                      return FilledButton(
                                          onPressed: () {
                                            setState(() {
                                              _sensorType = sensorTitles[index];
                                              print(
                                                  'Updated sensorType: $_sensorType'); // Debugging
                                            });
                                          },
                                          child: Text(sensorTitles[index]));
                                    },
                                  ));
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Expanded(
                //   child: FutureBuilder<List<SensorData>>(
                //     future: _sensorDataFuture,
                //     builder: (context, snapshot) {
                //       if (snapshot.connectionState == ConnectionState.waiting) {
                //         // While the future is loading, show a loading indicator
                //         return const CircularProgressIndicator();
                //       } else if (snapshot.hasError) {
                //         // If the future completed with an error, show an error message
                //         return Text('Error: ${snapshot.error}');
                //       } else if (!snapshot.hasData) {
                //         // If the future completed but returned no data, show a message
                //         return const Text('No sensor data available.');
                //       } else {
                //         // If the future completed with data, display the list
                //         List<SensorData> sensorData = snapshot.data!;

                //         return Text(sensorData.length.toString());
                //       }
                //     },
                //   ),
                // ),
              ],
            );
          }
        },
      ),
    );
  }
}
