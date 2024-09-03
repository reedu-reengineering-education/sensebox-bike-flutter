import 'package:ble_app/blocs/sensor_bloc.dart';
import 'package:ble_app/providers/recording_state_provider.dart';
import 'package:ble_app/services/isar_service.dart';
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
    final bleBloc = BleBloc();
    final isarService = IsarService();
    final geolocationBloc = GeolocationBloc(isarService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => bleBloc),
        ChangeNotifierProvider(create: (_) => geolocationBloc),
        ChangeNotifierProvider(create: (_) => RecordingState()),
        ChangeNotifierProvider(
            create: (_) => SensorBloc(bleBloc, geolocationBloc)),
      ],
      child: MaterialApp(
        title: 'senseBox:bike',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green, brightness: Brightness.light),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
