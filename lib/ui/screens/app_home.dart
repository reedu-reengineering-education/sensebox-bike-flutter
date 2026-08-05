import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;

  final GlobalKey<TracksScreenState> _tracksScreenKey =
      GlobalKey<TracksScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      TracksScreen(key: _tracksScreenKey),
      const SettingsScreen(),
      const LoginScreen(),
    ];
  }

  void _onDestinationSelected(int value) {
    setState(() {
      _selectedIndex = value;
      if (value == 1) {
        _tracksScreenKey.currentState?.refreshTracks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
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
            onDestinationSelected: _onDestinationSelected,
            selectedIndex: _selectedIndex,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.map),
                label: l10n.homeBottomBarHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.route),
                label: l10n.homeBottomBarTracks,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings),
                label: l10n.generalSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
