import 'package:flutter/material.dart';
import '../../blocs/ble_bloc.dart';

class BleDataWidget extends StatelessWidget {
  final BleBloc bleBloc;

  const BleDataWidget({super.key, required this.bleBloc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<double>>(
      stream: bleBloc.getCharacteristicStream('b3491b60-c0f3-4306-a30d-49c91f37a62b').stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text('No data received from characteristic.');
        }
    
        // Display data
        return Text('Data: ${snapshot.data!.join(', ')}');
      },
    );


    // return StreamBuilder<List<Map<String, List<double>>>>(
    //     stream: bleBloc.bleDataStream,
    //     builder: (context, snapshot) {
    //       if (snapshot.connectionState == ConnectionState.waiting) {
    //         return const Center(child: CircularProgressIndicator());
    //       } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
    //         return const Center(child: Text('No devices connected'));
    //       } else {
    //         return ListView.builder(
    //           itemCount: snapshot.data!.length,
    //           itemBuilder: (context, index) {
    //             final data = snapshot.data![index];
    //             return ListTile(
    //               title: Text(data.keys.first),
    //               subtitle: Text(data.values.toString()),
    //             );
    //           },
    //         );
    //       }
    //     },
    //   ); 
       }
}
