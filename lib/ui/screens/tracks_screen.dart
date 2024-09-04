import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/track_detail_screen.dart';

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
              return const Text('No tracks available.');
            } else {
              // If the future completed with data, display the list
              List<TrackData> tracks = snapshot.data!;
              return ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  TrackData track = tracks[index];
                  return ListTile(
                    title: Text('Track ${track.id}'),
                    subtitle:
                        Text('Geolocations: ${track.geolocations.length}'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TrackDetailScreen(
                                id: track.id,
                              )),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
