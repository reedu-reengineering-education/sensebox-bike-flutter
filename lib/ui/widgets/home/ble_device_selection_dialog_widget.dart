import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) {
  bleBloc.startScanning();

  showModalBottomSheet<void>(
    showDragHandle: true,
    context: context,
    builder: (BuildContext context) {
      return Column(
        children: [
          Text(AppLocalizations.of(context)!.bleDeviceSelectTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(
            height: 300,
            child: StreamBuilder<List<BluetoothDevice>>(
              stream: bleBloc.devicesListStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const Center(
                    heightFactor: 0,
                    child: CircularProgressIndicator(),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final device = snapshot.data![index];
                    return ListTile(
                      title: Text(device.platformName),
                      onTap: () {
                        bleBloc.connectToDevice(device, context);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      );
    },
  );
}
