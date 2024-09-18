import 'package:intl/intl.dart';
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
              return Center(
                  child: Text('No tracks available.',
                      style: Theme.of(context).textTheme.bodyMedium));
            } else {
              // If the future completed with data, display the list
              List<TrackData> tracks = snapshot.data!;
              return ListView.builder(
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  TrackData track = tracks[index];
                  return Dismissible(
                      key: Key(track.id.toString()),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (DismissDirection direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Delete Track"),
                              content: const Text(
                                  "Are you sure you wish to delete this track?"),
                              actions: <Widget>[
                                FilledButton(
                                    style: const ButtonStyle(
                                        backgroundColor: WidgetStatePropertyAll(
                                            Colors.redAccent)),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text("Delete")),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) async => {
                            await IsarService()
                                .trackService
                                .deleteTrack(track.id),
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Track ${track.id} deleted')),
                            )
                          },
                      child: ListTile(
                        title: Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss')
                              .format(track.geolocations.first.timestamp),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined),
                                const SizedBox(width: 8),
                                Text(
                                    '${DateFormat('mm:ss').format(DateTime.fromMillisecondsSinceEpoch(track.duration.inMilliseconds))} min',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.route),
                                const SizedBox(width: 8),
                                Text('${track.distance.toStringAsFixed(2)} km',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => TrackDetailScreen(
                                    id: track.id,
                                  )),
                        ),
                      ));
                },
              );
            }
          },
        ),
      ),
    );
  }
}
