import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/screens/home_screen.dart';
import 'package:sensebox_bike/ui/screens/login_screen.dart';
import 'package:sensebox_bike/ui/screens/settings_screen.dart';
import 'package:sensebox_bike/ui/screens/tracks_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  _AppHomeState createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    TracksScreen(),
    SettingsScreen(),
    LoginScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context);
    final isAuthenticated = openSenseMapBloc.isAuthenticated;
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => _pages[_selectedIndex],
          );
        },
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
          child: NavigationBar(
            onDestinationSelected: (value) {
              setState(() {
                if (value == 3) {
                  if (isAuthenticated) {
                    openSenseMapBloc.logout();
                  } else {
                    _selectedIndex = value;
                  }
                } else {
                  _selectedIndex = value;
                }
              });
            },
            selectedIndex: _selectedIndex,
            destinations: [
              NavigationDestination(
                  icon: Icon(Icons.map),
                  label: localizations.homeBottomBarHome),
              NavigationDestination(
                  icon: Icon(Icons.route),
                  label: localizations.homeBottomBarTracks),
              NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: localizations.generalSettings),
              NavigationDestination(
                  icon: Icon(isAuthenticated ? Icons.logout : Icons.login),
                  label: isAuthenticated
                      ? localizations.generalLogout
                      : localizations.generalLogin),
            ],
          ),
        ),
      ),
    );
  }
}
