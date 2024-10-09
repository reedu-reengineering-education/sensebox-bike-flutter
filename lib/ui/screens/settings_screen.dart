import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          // Settings Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          StreamBuilder<bool>(
            stream: settingsBloc.vibrateOnDisconnectStream,
            initialData: settingsBloc.vibrateOnDisconnect,
            builder: (context, snapshot) {
              return ListTile(
                leading: const Icon(Icons.vibration),
                title: const Text('Vibrate on disconnect'),
                trailing: Switch(
                  value: snapshot.data ?? false,
                  onChanged: (value) {
                    settingsBloc.toggleVibrateOnDisconnect(value);
                  },
                ),
              );
            },
          ),

          // Other Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Other',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            subtitle: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                      'Version: ${snapshot.data!.version}+${snapshot.data!.buildNumber}');
                } else {
                  return const Text('Loading...');
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              launchUrl(Uri.parse(
                  'https://sensebox.de/sensebox-bike-privacy-policy'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail),
            title: const Text('Contact'),
            onTap: () {
              launchUrl(Uri.parse(
                  'mailto:kontakt@reedu.de?subject=senseBox:bike%20App'));
            },
          ),
        ],
      ),
    );
  }
}
