import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
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

  final List<Widget> _pages = const [
    HomeScreen(),
    TracksScreen(),
    SettingsScreen(),
    LoginScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final openSenseMapBloc = Provider.of<OpenSenseMapBloc>(context);

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
            onDestinationSelected: (value) {
              setState(() {
                if (value == 3) {
                  // If the user selects the login/logout destination
                  if (openSenseMapBloc.isAuthenticated) {
                    // Log out the user if authenticated
                    openSenseMapBloc.logout();
                  } else {
                    // Navigate to the login screen if not authenticated
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
                  label: AppLocalizations.of(context)!.homeBottomBarHome),
              NavigationDestination(
                  icon: Icon(Icons.route),
                  label: AppLocalizations.of(context)!.homeBottomBarTracks),
              NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.generalSettings),
              NavigationDestination(
                  icon: Icon(openSenseMapBloc.isAuthenticated
                      ? Icons.logout
                      : Icons.login),
                  label: openSenseMapBloc.isAuthenticated
                      ? AppLocalizations.of(context)!.generalLogout
                      : AppLocalizations.of(context)!.generalLogin),
            ],
          ),
        ),
      ),
    );
  }
}
