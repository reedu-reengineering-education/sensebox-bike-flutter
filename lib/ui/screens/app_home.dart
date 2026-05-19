import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/services/permission_service.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;

  final GlobalKey<TracksScreenState> _tracksScreenKey =
      GlobalKey<TracksScreenState>();

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      PermissionService.requestInitialLocationPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(isMapActive: _selectedIndex == 0),
          TracksScreen(key: _tracksScreenKey),
          const SettingsScreen(),
          const LoginScreen(),
        ],
      ),
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
              if (value == 1) {
                _tracksScreenKey.currentState?.refreshTracks();
              }
            },
            selectedIndex: _selectedIndex,
            destinations: [
              NavigationDestination(
                  icon: Icon(Icons.map),
                  label: AppLocalizations.of(context)!.homeBottomBarHome),
              NavigationDestination(
                  icon: Icon(Icons.route),
                  label: AppLocalizations.of(context)!.homeBottomBarTracks),
              NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.generalSettings),
            ],
          ),
        ),
      ),
    );
  }
}
