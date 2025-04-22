import 'package:sensebox_bike/blocs/ble_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/widgets/common/custom_spacer.dart';

void showDeviceSelectionDialog(BuildContext context, BleBloc bleBloc) async {
  try {
    await bleBloc.startScanning();
  } catch (e, stack) {
    ErrorService.handleError(e, stack);
    return;
  }

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
                    return Column(
                      children: [
                        CustomSpacer(), // Add spacing between tiles
                        Container(
                          width: MediaQuery.of(context).size.width *
                              0.9, // Set width to 80% of the screen
                          margin: const EdgeInsets.only(
                              top: 12), // Add margin above each item
                          child: ListTile(
                            title: Text(device.platformName),
                            trailing: const Icon(
                                Icons.arrow_forward_ios), // Add an arrow icon
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline, // Add border color
                                width: 1, // Border width
                              ),
                              borderRadius: BorderRadius.circular(
                                  32), // Add rounded corners
                            ),
                            onTap: () {
                              bleBloc.connectToDevice(device, context);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
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
