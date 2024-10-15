import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  static final List<Widget> _pages = <Widget>[
    const PopScope(
      canPop: false,
      child: HomeScreen(),
    ),
    const PopScope(
      canPop: false,
      child: TracksScreen(),
    ),
    const PopScope(
      canPop: false,
      child: SettingsScreen(),
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(24), topLeft: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black38, spreadRadius: 0, blurRadius: 12),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: NavigationBar(
            onDestinationSelected: (value) {
              setState(() {
                _selectedIndex = value;
              });
            },
            selectedIndex: _selectedIndex,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.route), label: 'Tracks'),
              NavigationDestination(
                  icon: Icon(Icons.settings), label: 'Settings')
            ],
          ),
        ),
      ),
    );
  }
}
