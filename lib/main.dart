import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'blocs/ble_bloc.dart';
import 'blocs/geolocation_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isarService = IsarService();
    final bleBloc = BleBloc();
    final recordingBloc = RecordingBloc(isarService);
    final geolocationBloc = GeolocationBloc(isarService, recordingBloc);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => recordingBloc), // Initialize first
        ChangeNotifierProvider(create: (_) => geolocationBloc),
        ChangeNotifierProvider(create: (_) => bleBloc),
        ChangeNotifierProvider(
            create: (_) => SensorBloc(bleBloc, geolocationBloc)),
        ChangeNotifierProvider(create: (_) => TrackBloc(isarService)),
      ],
      child: MaterialApp(
        title: 'senseBox:bike',
        theme: ThemeData(
          primaryColor: Colors.black,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
