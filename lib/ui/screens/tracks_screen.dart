import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';

class TracksScreen extends StatefulWidget {
  const TracksScreen({super.key});

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  late Future<List<TrackData>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState to avoid re-fetching data unnecessarily
    _tracksFuture = IsarService().trackService.getAllTracks();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _tracksFuture = IsarService().trackService.getAllTracks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Padding(
            padding:
                const EdgeInsets.only(bottom: 4.0), // Adds padding to the top
            child: FutureBuilder<List<TrackData>>(
              future: _tracksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center elements
                    children: [
                      const Icon(Icons.route),
                      const SizedBox(width: 8),
                      Text('Loading...',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text('Loading...',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.straighten),
                      const SizedBox(width: 8),
                      Text('Loading...',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center elements
                    children: [
                      const Icon(Icons.route),
                      const SizedBox(width: 8),
                      Text('Error: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text('Error: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.straighten),
                      const SizedBox(width: 8),
                      Text('Error: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center elements
                    children: [
                      const Icon(Icons.route),
                      const SizedBox(width: 8),
                      Text('0 Tracks',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text('0h 00min',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.straighten),
                      const SizedBox(width: 8),
                      Text('0.00 km',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  );
                } else {
                  List<TrackData> tracks = snapshot.data!;
                  // Calculate total duration and distance
                  const zeroDuration = Duration(milliseconds: 0);
                  Duration totalDuration = tracks.fold(
                      zeroDuration, (prev, track) => prev + track.duration);
                  double totalDistance =
                      tracks.fold(0.0, (prev, track) => prev + track.distance);

                  // Format duration as '1h 27min'
                  int hours = totalDuration.inHours;
                  int minutes = totalDuration.inMinutes.remainder(60);
                  String formattedDuration = '${hours}h ${minutes}min';

                  return Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center elements
                    children: [
                      const Icon(Icons.route),
                      const SizedBox(width: 8),
                      Text('${tracks.length} Tracks',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text(formattedDuration,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 24), // Space between entries
                      const Icon(Icons.straighten),
                      const SizedBox(width: 8),
                      Text('${totalDistance.toStringAsFixed(2)} km',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<TrackData>>(
          future: _tracksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // While the future is loading, show a loading indicator
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // If the future completed with an error, show an error message
              return Text('Error: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // If the future completed but returned no data, show a message
              return Center(
                  child: Text('No tracks available.',
                      style: Theme.of(context).textTheme.bodyMedium));
            } else {
              // If the future completed with data, display the list
              List<TrackData> tracks = snapshot.data!;

              // filter tracks without geolocation data
              tracks = tracks
                  .where((track) => track.geolocations.isNotEmpty)
                  .toList()
                  .reversed
                  .toList();

              if (tracks.isEmpty) {
                return Center(
                    child: Text('No tracks available.',
                        style: Theme.of(context).textTheme.bodyMedium));
              }

              return ListView.separated(
                separatorBuilder: (context, index) => const SizedBox(
                  height: 24,
                ),
                padding: const EdgeInsets.only(top: 24),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  TrackData track = tracks[index];
                  return TrackListItem(
                      track: track,
                      onDismissed: () async {
                        await IsarService().trackService.deleteTrack(track.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Track ${track.id} deleted')),
                        );
                      });
                },
              );
            }
          },
        ),
      ),
    );
  }
}
