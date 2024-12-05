import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/ui/screens/exclusion_zones_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBloc = Provider.of<SettingsBloc>(context);
    final bleBloc = Provider.of<BleBloc>(context);

    final ssidController = TextEditingController();
    final passwordController = TextEditingController();

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
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Privacy Zones'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExclusionZonesScreen()),
            ),
            trailing: Badge.count(
              count: settingsBloc.privacyZones.length,
              backgroundColor: Theme.of(context).iconTheme.color,
            ),
          ),
          // List tile called "Software Update" which opens a dialog with a text field to enter the SSID and password of the wifi network
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Software Update'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Software Update'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                            'Enter the SSID and password of the WiFi network to which the senseBox should connect to update the software.'),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'SSID',
                          ),
                          controller: ssidController,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          controller: passwordController,
                        ),
                      ],
                    ),
                    actions: [
                      // Button to cancel the dialog
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      // Button to confirm the dialog
                      FilledButton(
                        onPressed: () async {
                          await bleBloc.sendWifiCredentials(
                            ssidController.text,
                            passwordController.text,
                          );

                          Navigator.pop(context);
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  );
                },
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
