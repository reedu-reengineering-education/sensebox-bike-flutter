import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensebox_bike/feature_flags.dart';
import 'package:sensebox_bike/models/sensor_data.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/widgets/common/loader.dart';
import 'package:sensebox_bike/ui/widgets/track/export_button.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/utils/sensor_utils.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  Future<void> _shareFile(String filePath) async {
    final localization = AppLocalizations.of(context)!;

    try {
      await Share.shareXFiles([XFile(filePath)],
          text: localization.trackDetailsExport);
    } catch (e) {
      ErrorService.handleError('Error sharing file: $e', StackTrace.current);
    }
  }

  Future<void> _handleAndroidExport(String csvFilePath) async {
    final localization = AppLocalizations.of(context)!;

    try {
      DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;

      // check if api level is smaller than 33
      if (androidInfo.version.sdkInt < 33) {
        PermissionStatus status = await Permission.storage.request();

        if (!status.isGranted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(localization.trackDetailsPermissionsError),
            action: SnackBarAction(
                label: localization.generalSettings,
                onPressed: () => openAppSettings()),
          ));
          return;
        }
      }

      Directory? directory;

      if (defaultTargetPlatform == TargetPlatform.android) {
        //downloads folder - android only - API>30
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null || !directory.existsSync()) {
        ErrorService.handleError(
            ExportDirectoryAccessError(), StackTrace.current);
        return;
      }

      // copy file to external storage
      final file = File(csvFilePath);
      final newName = file.path.split('/').last;
      final newPath = '${directory.path}/$newName';

      await file.copy(newPath);

      if (context.mounted) {
        // show snackbar
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(localization.trackDetailsFileSaved),
          action: SnackBarAction(
            label: localization.generalShare,
            onPressed: () async {
              await _shareFile(newPath);
            },
          ),
        ));
      }
    } catch (e) {
      await _shareFile(csvFilePath);
    }
  }

  Future<void> _exportTrackToCsv({bool isOpenSourceMapCompatible = false}) async {
    setState(() => _isDownloading = true);

    try {
      final isarService = IsarService();
      final String csvFilePath;
      
      if (isOpenSourceMapCompatible) {
        csvFilePath =
            await isarService.exportTrackToCsvInOpenSenseMapFormat(id);
      } else {
        csvFilePath = await isarService.exportTrackToCsv(id);
      }

      // if android, save to external storage
      // if ios, open share dialog

      if (Platform.isAndroid) {
        await _handleAndroidExport(csvFilePath);
        // try {
        //   DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
        //   final androidInfo = await deviceInfoPlugin.androidInfo;

        //   // check if api level is smaller than 33
        //   if (androidInfo.version.sdkInt < 33) {
        //     PermissionStatus status = await Permission.storage.request();

        //     if (!status.isGranted && context.mounted) {
        //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        //         content: Text(localization.trackDetailsPermissionsError),
        //         action: SnackBarAction(
        //             label: localization.generalSettings,
        //             onPressed: () => openAppSettings()),
        //       ));
        //       return;
        //     }
        //   }

        //   Directory? directory;

        //   if (defaultTargetPlatform == TargetPlatform.android) {
        //     //downloads folder - android only - API>30
        //     directory = Directory('/storage/emulated/0/Download');
        //   } else {
        //     directory = await getExternalStorageDirectory();
        //   }

        //   if (directory == null || !directory.existsSync()) {
        //     ErrorService.handleError(
        //         ExportDirectoryAccessError(), StackTrace.current);
        //     return;
        //   }

        //   // copy file to external storage
        //   final file = File(csvFilePath);

        //   final newName = file.path.split('/').last;
        //   final newPath = '${directory.path}/$newName';

        //   await file.copy(newPath);

        //   if (context.mounted) {
        //     // show snackbar
        //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        //       content: Text(localization.trackDetailsFileSaved),
        //       action: SnackBarAction(
        //         label: localization.generalShare,
        //         onPressed: () {
        //           Share.shareXFiles([XFile(newPath)],
        //               text: localization.trackDetailsExport);
        //         },
        //       ),
        //     ));
        //   }
        // } catch (e) {
        //   var text = context.mounted
        //       ? localization.trackDetailsExport
        //       : 'Track data CSV export.';
        //   Share.shareXFiles([XFile(csvFilePath)], text: text);
        // }
      } else if (Platform.isIOS) {
        // await Share.shareXFiles([XFile(csvFilePath)],
        //     text: localization.trackDetailsExport);
        await _shareFile(csvFilePath);
      }
    } catch (e) {
      ErrorService.handleError('Error exporting CSV: $e', StackTrace.current);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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
          return Text(errorText ??
              AppLocalizations.of(context)!
                  .generalErrorWithDescription(snapshot.error.toString()));
        } else if (!snapshot.hasData) {
          return Text(
              noDataText ?? AppLocalizations.of(context)!.trackDetailsNoData);
        } else {
          return builder(snapshot.data as T);
        }
      },
    );
  }

  Future<List<dynamic>> get _combinedFutures =>
      Future.wait([_trackFuture, _sensorDataFuture]);

  Widget _buildAppBarTitle(
      BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
    final localizations = AppLocalizations.of(context)!;

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: Loader(light: true));
    } else if (snapshot.hasError) {
      return Text(localizations.trackDetailsLoadingError);
    } else if (!snapshot.hasData ||
        snapshot.data![0] == null ||
        (snapshot.data![1] as List).isEmpty) {
      return Row(children: [Text(localizations.trackDetailsNoTrackData)]);
    } else {
      final track = snapshot.data![0] as TrackData;
      final sensorData = snapshot.data![1] as List<SensorData>;
      final isDisabled = sensorData.isEmpty;

      return Row(
        children: [
          Text(DateFormat('yyyy-MM-dd HH:mm')
              .format(track.geolocations.first.timestamp)),
          const Spacer(),
          ExportButton(
            isDownloading: _isDownloading,
            isDisabled: isDisabled,
            onExport: (selectedFormat) async {
              if (selectedFormat == 'regular') {
                await _exportTrackToCsv();
              } else if (selectedFormat == 'openSenseMap') {
                await _exportTrackToCsv(isOpenSourceMapCompatible: true);
              }
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<List<dynamic>>(
          future: _combinedFutures,
          builder: (context, snapshot) => _buildAppBarTitle(context, snapshot),
        ),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: _buildFutureBuilder<TrackData?>(
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
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [
                    Container(
                        height: 12,
                        decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(
                              Radius.circular(20),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                Colors.green,
                                Colors.orange,
                                Colors.red,
                              ], // Gradient from https://learnui.design/tools/gradient-generator.html
                              tileMode: TileMode.mirror,
                            ))),
                    _buildFutureBuilder<TrackData?>(
                      future: _trackFuture,
                      builder: (track) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(getMinSensorValue(
                                    track!.geolocations.toList(), _sensorType)
                                .toStringAsFixed(1)),
                            const Spacer(),
                            Text(getMaxSensorValue(
                                    track.geolocations.toList(), _sensorType)
                                .toStringAsFixed(1)),
                          ]),
                      errorText: AppLocalizations.of(context)!
                          .trackDetailsLoadingError,
                      noDataText:
                          AppLocalizations.of(context)!.trackDetailsNoTrackData,
                    )
                  ])),
              SizedBox(
                height: 100,
                child: _buildFutureBuilder<List<SensorData>>(
                  future: _sensorDataFuture,
                  builder: (sensorData) {
                    // Your sensorData processing and UI logic here
                    List<Map<String, String?>> sensorTitles = sensorData
                        .map(
                            (e) => {'title': e.title, 'attribute': e.attribute})
                        .map((map) => map.entries
                            .map((e) => '${e.key}:${e.value}')
                            .join(','))
                        .toSet()
                        .map((str) {
                      var entries = str.split(',').map((e) => e.split(':'));
                      return Map<String, String?>.fromEntries(
                        entries.map((e) =>
                            MapEntry(e[0], e[1] == 'null' ? null : e[1])),
                      );
                    }).toList();

                    // Filter out surface_anomaly if the feature flag is enabled
                    if (FeatureFlags.hideSurfaceAnomalySensor) {
                      sensorTitles.removeWhere(
                          (sensor) => sensor['title'] == 'surface_anomaly');
                    }

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

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sensorTitles.length,
                      itemBuilder: (context, index) {
                        String title = sensorTitles[index]['title']!;
                        String? attribute = sensorTitles[index]['attribute'];
                        String displayTitle =
                            getTranslatedTitleFromSensorKey(
                                title, attribute, context) ??
                            title;

                        return Card.filled(
                          clipBehavior: Clip.hardEdge,
                          color: _sensorType ==
                                  '$title${attribute == null ? '' : '_$attribute'}'
                              ? getSensorColor(title).withOpacity(0.25)
                              : Theme.of(context).canvasColor,
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
                    );
                  },
                ),
              )
            ],
          ),
          errorText: AppLocalizations.of(context)!.trackDetailsLoadingError,
          noDataText: AppLocalizations.of(context)!.trackDetailsNoTrackData,
        ),
      ),
    );
  }
}
