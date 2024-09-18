import 'package:intl/intl.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
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
  bool _isDownloading = false; // Flag to show loading spinner
  late String _sensorType;

  _TrackDetailScreenState(this.id);

  @override
  void initState() {
    super.initState();
    _sensorType = 'temperature'; // Default sensor type
    _trackFuture = IsarService().trackService.getTrackById(id);
    _sensorDataFuture = IsarService().sensorService.getSensorDataByTrackId(id);
  }

  List<String> getSensorTitles(List<SensorData> sensorData) {
    return sensorData
        .map((e) => getTitleFromSensorKey(e.title, e.attribute) ?? '')
        .toSet()
        .toList();
  }

  Future<void> _exportTrackToCsv() async {
    setState(() {
      _isDownloading = true; // Show spinner
    });

    try {
      final isarService = IsarService();
      final csvFilePath = await isarService.exportTrackToCsv(id);
      await Share.shareXFiles([XFile(csvFilePath)],
          text: 'Track data CSV export.');
    } catch (e) {
      print('Error exporting CSV: $e');
    } finally {
      setState(() {
        _isDownloading = false; // Hide spinner
      });
    }
  }

  Widget _buildFutureBuilder<T>({
    required Future<T> future,
    required Widget Function(T data) builder,
    String? errorText,
    String? noDataText,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text(errorText ?? 'Error: ${snapshot.error}');
        } else if (!snapshot.hasData) {
          return Text(noDataText ?? 'No data available.');
        } else {
          return builder(snapshot.data!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildFutureBuilder<TrackData?>(
          future: _trackFuture,
          builder: (track) => Text(DateFormat('yyyy-MM-dd HH:mm')
              .format(track!.geolocations.first.timestamp)),
          errorText: 'Error loading track',
          noDataText: 'No track available',
        ),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    height: 32.0,
                    width: 32.0,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : IconButton(
                  onPressed: _exportTrackToCsv,
                  icon: const Icon(Icons.file_download),
                ),
        ],
      ),
      body: _buildFutureBuilder<TrackData?>(
        future: _trackFuture,
        builder: (track) => Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card.filled(
                  clipBehavior: Clip.hardEdge,
                  elevation: 4,
                  child: TrajectoryWidget(
                    geolocationData: track!.geolocations.toList(),
                    sensorType: _sensorType,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _buildFutureBuilder<List<SensorData>>(
                future: _sensorDataFuture,
                builder: (sensorData) {
                  // Your sensorData processing and UI logic here
                  List<Map<String, String?>> sensorTitles = sensorData
                      .map((e) => {'title': e.title, 'attribute': e.attribute})
                      .map((map) => map.entries
                          .map((e) => '${e.key}:${e.value}')
                          .join(','))
                      .toSet()
                      .map((str) {
                    var entries = str.split(',').map((e) => e.split(':'));
                    return Map<String, String?>.fromEntries(
                      entries.map(
                          (e) => MapEntry(e[0], e[1] == 'null' ? null : e[1])),
                    );
                  }).toList();

                  List<String> order = [
                    'temperature',
                    'humidity',
                    'distance',
                    'overtaking',
                    'surface_classification_asphalt',
                    'surface_classification_compacted',
                    'surface_classification_paving',
                    'surface_classification_sett',
                    'surface_classification_standing',
                    'surface_anomaly',
                    'acceleration_x',
                    'acceleration_y',
                    'acceleration_z',
                    'finedust_pm1',
                    'finedust_pm2.5',
                    'finedust_pm4',
                    'finedust_pm10',
                    'gps_latitude',
                    'gps_longitude',
                    'gps_speed',
                  ];

                  sensorTitles.sort((a, b) {
                    int indexA = order.indexOf(
                        '${a['title']}${a['attribute'] == null ? '' : '_${a['attribute']}'}');
                    int indexB = order.indexOf(
                        '${b['title']}${b['attribute'] == null ? '' : '_${b['attribute']}'}');
                    return indexA.compareTo(indexB);
                  });

                  return SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sensorTitles.length,
                      itemBuilder: (context, index) {
                        String title = sensorTitles[index]['title']!;
                        String? attribute = sensorTitles[index]['attribute'];
                        String displayTitle =
                            getTitleFromSensorKey(title, attribute) ?? title;

                        return Card.filled(
                          clipBehavior: Clip.hardEdge,
                          color: _sensorType ==
                                  '$title${attribute == null ? '' : '_$attribute'}'
                              ? getSensorColor(title).withOpacity(0.1)
                              : Colors.white,
                          child: InkWell(
                            onTap: () => setState(() {
                              _sensorType =
                                  '$title${attribute == null ? '' : '_$attribute'}';
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 8),
                              child: Column(
                                children: [
                                  Container(
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: getSensorColor(title)
                                          .withOpacity(0.1),
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      getSensorIcon(title),
                                      size: 24,
                                      color: getSensorColor(title),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      displayTitle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: getSensorColor(title),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        errorText: 'Error loading track',
        noDataText: 'No track available',
      ),
    );
  }
}
