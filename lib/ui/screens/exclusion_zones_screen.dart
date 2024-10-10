import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';

class ExclusionZonesScreen extends StatefulWidget {
  ExclusionZonesScreen({super.key});

  @override
  State<ExclusionZonesScreen> createState() => _ExclusionZonesScreenState();
}

class _ExclusionZonesScreenState extends State<ExclusionZonesScreen> {
  List<Point> polygonPoints = []; // To store the tapped points
  List<CircleAnnotation> circleAnnotations = []; // To store circle annotations
  PolygonAnnotation? _currentPolygon;
  bool isEditing = false; // To track editing state
  bool isLoading = false; // To track loading state

  CircleAnnotationManager? circleAnnotationManager; // Storing polygon corners
  PolygonAnnotationManager? polygonAnnotationManager; // Storing the polygon

  void _onMapCreated(MapboxMap controller) async {
    circleAnnotationManager =
        await controller.annotations.createCircleAnnotationManager();

    circleAnnotationManager!.setCircleEmissiveStrength(1);
    circleAnnotationManager!.setCirclePitchAlignment(CirclePitchAlignment.MAP);

    polygonAnnotationManager =
        await controller.annotations.createPolygonAnnotationManager();

    polygonAnnotationManager!.setFillEmissiveStrength(1);

    controller.setOnMapTapListener(_onMapTapListener);
  }

  void _onMapTapListener(MapContentGestureContext context) async {
    if (!isEditing || isLoading)
      return; // Only add points when editing and not loading

    setState(() {
      isLoading = true; // Start loading
      polygonPoints.add(context.point); // Add the tapped point to the list
    });

    try {
      // If there are more than 2 points, update the polygon
      if (polygonPoints.length > 2) {
        print('Updating polygon with ${polygonPoints.length} points');

        // create a polygon with the points if not exists
        _currentPolygon ??= await polygonAnnotationManager!.create(
          PolygonAnnotationOptions(
            geometry: Polygon.fromPoints(points: [polygonPoints.toList()]),
            fillColor: Colors.blue.value,
            fillOpacity: 0.5,
          ),
        );

        // update the polygon with the new points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [polygonPoints.toList()]);

        await polygonAnnotationManager!.update(_currentPolygon!);
      }

      // Create a visual marker (circle) at the tapped point
      final circleAnnotation = await circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: context.point,
          circleColor: Colors.blue.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2,
          circleRadius: 6,
        ),
      );

      // Store the circle annotation for future removal
      circleAnnotations.add(circleAnnotation);
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  // Undo the last added point and remove the corresponding circle
  void _undoLastPoint() async {
    if (polygonPoints.isEmpty || isLoading) return;

    setState(() {
      isLoading = true; // Start loading
      polygonPoints.removeLast(); // Remove the last point
    });

    try {
      // Remove the last circle annotation
      if (circleAnnotations.isNotEmpty) {
        final lastCircle = circleAnnotations.removeLast();
        await circleAnnotationManager!.delete(lastCircle);
      }

      if (polygonPoints.length >= 2) {
        // Update the polygon with the remaining points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [polygonPoints.toList()]);

        await polygonAnnotationManager!.update(_currentPolygon!);
      } else {
        // If less than 2 points, remove the polygon completely
        if (_currentPolygon != null) {
          await polygonAnnotationManager!.delete(_currentPolygon!);
          _currentPolygon = null;
        }
      }
    } finally {
      setState(() {
        isLoading = false; // End loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exclusion Zones'),
      ),
      body: Stack(
        children: [
          ReusableMapWidget(
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            child: Column(
              children: [
                // Toggle button for editing state
                IconButton.filled(
                  icon: isEditing
                      ? const Icon(Icons.done) // Show "done" when editing
                      : const Icon(Icons.add), // Show "add" when not editing
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () async {
                          if (polygonAnnotationManager == null) {
                            return;
                          }

                          setState(() {
                            isLoading = true; // Start loading
                          });

                          try {
                            if (isEditing && polygonPoints.isEmpty) {
                              // If editing and no points, cancel the editing
                              setState(() {
                                isEditing = false; // Toggle editing state off
                              });
                            } else if (isEditing && polygonPoints.isNotEmpty) {
                              await polygonAnnotationManager!
                                  .delete(_currentPolygon!);
                              _currentPolygon = null;

                              // If editing, create the polygon and complete the editing
                              await polygonAnnotationManager!.create(
                                PolygonAnnotationOptions(
                                  geometry: Polygon.fromPoints(
                                      points: [polygonPoints.toList()]),
                                  fillColor: Colors.blue.value,
                                  fillOpacity: 0.5,
                                ),
                              );

                              setState(() {
                                polygonPoints.clear();
                                circleAnnotations.clear();
                                isEditing = false; // Toggle editing state off
                              });
                            } else {
                              // Start editing mode
                              setState(() {
                                isEditing = true; // Toggle editing state on
                                _currentPolygon = null; // Reset polygon
                              });
                            }
                          } finally {
                            setState(() {
                              isLoading = false; // End loading
                            });
                          }
                        },
                ),
                // Undo button
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: isLoading || polygonPoints.isEmpty
                      ? null // Disable if loading or no points to undo
                      : _undoLastPoint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
