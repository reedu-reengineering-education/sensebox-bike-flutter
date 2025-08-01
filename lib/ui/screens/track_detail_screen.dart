import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/ui/widgets/track/export_button.dart';
import 'package:sensebox_bike/ui/widgets/track/trajectory_widget.dart';
import 'package:sensebox_bike/utils/track_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/track/sensor_tile_list.dart';

class TrackDetailScreen extends StatefulWidget {
  final TrackData track;

  const TrackDetailScreen({super.key, required this.track});

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  late final IsarService isarService;
  bool _isDownloading = false;
  late String _sensorType = 'temperature';
  List<GeolocationData> _geolocations = [];
  bool _isLoading = true;

  _TrackDetailScreenState();

  @override
  void initState() {
    super.initState();
    isarService = Provider.of<TrackBloc>(context, listen: false).isarService;
    _loadTrackData();
  }

  Future<void> _loadTrackData() async {
    try {
      final geolocations = await isarService.geolocationService
          .getGeolocationDataWithPreloadedSensors(widget.track.id);
      setState(() {
        _geolocations = geolocations;
        _isLoading = false;
      });
    } catch (e) {
      ErrorService.handleError(
          'Error loading track data: $e', StackTrace.current);
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _exportTrackToCsv(
      {bool isOpenSourceMapCompatible = false}) async {
    setState(() => _isDownloading = true);

    try {
      final String csvFilePath;

      if (isOpenSourceMapCompatible) {
        csvFilePath =
            await isarService
            .exportTrackToCsvInOpenSenseMapFormat(widget.track.id);
      } else {
        csvFilePath = await isarService.exportTrackToCsv(widget.track.id);
      }

      // if android, save to external storage
      // if ios, open share dialog
      if (Platform.isAndroid) {
        _handleAndroidExport(csvFilePath);
      } else if (Platform.isIOS) {
        await Share.shareXFiles([XFile(csvFilePath)],
            text: AppLocalizations.of(context)!.trackDetailsExport);
      }
    } catch (e) {
      ErrorService.handleError('Error exporting CSV: $e', StackTrace.current);
    } finally {
      setState(() {
        _isDownloading = false; 
      });
    }
  }

  Widget _buildAppBarTitle(TrackData track) {
    String errorMessage = AppLocalizations.of(context)!.trackDetailsNoData;

    return Row(
      children: [
        Text(trackName(track, errorMessage: errorMessage)),
        const Spacer(),
        ExportButton(
          isDisabled: false,
          isDownloading: _isDownloading,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(widget.track)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_geolocations.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: _buildAppBarTitle(widget.track)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.trackDetailsNoData),
        ),
      );
    }

    // Get all unique sensor data from all geolocations in the track
    final sensorData = getAllUniqueSensorData(_geolocations);
    
    final minSensorValue =
        getMinSensorValue(_geolocations, _sensorType).toStringAsFixed(1);
    final maxSensorValue =
        getMaxSensorValue(_geolocations, _sensorType).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle(widget.track)),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card.filled(
                  clipBehavior: Clip.hardEdge,
                  elevation: 4,
                  child: TrajectoryWidget(
                      geolocationData: _geolocations, sensorType: _sensorType),
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
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(minSensorValue),
                    const Spacer(),
                    Text(maxSensorValue)
                  ])
                ])),
            SensorTileList(
              sensorData: sensorData,
              selectedSensorType: _sensorType,
              onSensorTypeSelected: (type) {
                setState(() {
                  _sensorType = type;
                });
              },
            )
          ],
        ),
      ),
    );
  }
}
