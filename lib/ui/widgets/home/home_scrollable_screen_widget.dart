import 'dart:math';

import 'package:sensebox_bike/blocs/sensor_bloc.dart';
import 'package:sensebox_bike/ui/widgets/home/geolocation_widget.dart';
import 'package:flutter/material.dart';

class HomeScrollableScreen extends StatelessWidget {
  final SensorBloc sensorBloc;

  const HomeScrollableScreen({super.key, required this.sensorBloc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        clipBehavior: Clip.none,
        slivers: [
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
                minHeight: 200.0,
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                child: Container(
                  // use theme color
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: const Padding(
                      padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Card(
                          elevation: 12,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: double.infinity,
                            child:
                                GeolocationMapWidget(), // Directly use the map widget
                          ))),
                )),
            pinned: true,
          ),
          SliverSafeArea(
            minimum: const EdgeInsets.fromLTRB(8, 24, 8, 48),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Number of columns
                crossAxisSpacing: 8, // Spacing between columns
                mainAxisSpacing: 8, // Spacing between rows
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final widgets = sensorBloc.getSensorWidgets();
                  return index < widgets.length ? widgets[index] : null;
                },
                childCount: sensorBloc.getSensorWidgets().length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => max(maxHeight, minHeight);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
