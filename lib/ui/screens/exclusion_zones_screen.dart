import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as Geolocator;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:sensebox_bike/ui/widgets/common/reusable_map_widget.dart';

class ExclusionZonesScreen extends StatefulWidget {
  const ExclusionZonesScreen({super.key});

  @override
  State<ExclusionZonesScreen> createState() => _ExclusionZonesScreenState();
}

class _ExclusionZonesScreenState extends State<ExclusionZonesScreen> {
  // Private Variables
  final List<Point> _polygonPoints = []; // To store the tapped points
  final List<CircleAnnotation> _circleAnnotations =
      []; // To store circle annotations
  PolygonAnnotation? _currentPolygon;
  bool _isEditing = false; // To track editing state
  bool _isLoading = false; // To track loading state

  CircleAnnotationManager?
      _circleAnnotationManager; // Managing circle annotations
  PolygonAnnotationManager?
      _polygonAnnotationManager; // Managing polygon annotations

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
            right: 8,
            top: 8,
            child: Column(
              children: [
                // Toggle Editing Button
                IconButton.filled(
                  icon: _isEditing
                      ? const Icon(Icons.done) // Show "done" when editing
                      : const Icon(Icons.add), // Show "add" when not editing
                  onPressed: _isLoading ? null : _toggleEditing,
                ),
                // Undo Button
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _isLoading || _polygonPoints.isEmpty
                      ? null
                      : _undoLastPoint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Initializes the map and sets up annotation managers.
  Future<void> _onMapCreated(MapboxMap controller) async {
    await controller.location.updateSettings(LocationComponentSettings(
      enabled: true,
      showAccuracyRing: true,
    ));

    // Get current position
    Geolocator.Position geoPosition =
        await Geolocator.Geolocator.getCurrentPosition();
    await controller.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(geoPosition.longitude, geoPosition.latitude),
        ),
        zoom: 14.0,
      ),
      MapAnimationOptions(duration: 1000),
    );

    // Initialize annotation managers
    _circleAnnotationManager = await controller.annotations
        .createCircleAnnotationManager(id: 'exclusion_zones_circle');

    _circleAnnotationManager!
      ..setCircleEmissiveStrength(1)
      ..setCirclePitchAlignment(CirclePitchAlignment.MAP);

    _polygonAnnotationManager = await controller.annotations
        .createPolygonAnnotationManager(below: 'exclusion_zones_circle');

    _polygonAnnotationManager!.setFillEmissiveStrength(1);

    _polygonAnnotationManager!
        .addOnPolygonAnnotationClickListener(_AnnotationClickListener());

    // Set map tap listener
    controller.setOnMapTapListener(_onMapTapListener);
  }

  /// Handles map tap events to add points to the polygon.
  Future<void> _onMapTapListener(MapContentGestureContext context) async {
    if (!_isEditing || _isLoading) {
      return; // Only add points when editing and not loading
    }

    setState(() {
      _isLoading = true; // Start loading
      _polygonPoints.add(context.point); // Add the tapped point to the list
    });

    try {
      // If there are more than 2 points, update the polygon
      if (_polygonPoints.length > 2) {
        print('Updating polygon with ${_polygonPoints.length} points');

        // Create a polygon if it doesn't exist
        _currentPolygon ??= await _polygonAnnotationManager!.create(
          PolygonAnnotationOptions(
            geometry: Polygon.fromPoints(points: [_polygonPoints.toList()]),
            fillColor: Colors.redAccent.value,
            fillOpacity: 0.5,
          ),
        );

        // Update the polygon with the new points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [_polygonPoints.toList()]);

        await _polygonAnnotationManager!.update(_currentPolygon!);
      }

      // Create a visual marker (circle) at the tapped point
      final circleAnnotation = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: context.point,
          circleColor: Colors.redAccent.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2,
          circleRadius: 6,
        ),
      );

      // Store the circle annotation for future removal
      _circleAnnotations.add(circleAnnotation);
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }

  /// Toggles the editing state and handles related UI changes.
  Future<void> _toggleEditing() async {
    if (_polygonAnnotationManager == null) {
      return;
    }

    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      if (_isEditing && _polygonPoints.isEmpty) {
        // If editing and no points, cancel the editing
        setState(() {
          _isEditing = false; // Toggle editing state off
        });
      } else if (_isEditing && _polygonPoints.isNotEmpty) {
        // Finalize editing by creating/updating the polygon
        if (_currentPolygon != null) {
          await _polygonAnnotationManager!.delete(_currentPolygon!);
          _currentPolygon = null;
        }

        // Create the final polygon
        await _polygonAnnotationManager!.create(
          PolygonAnnotationOptions(
            geometry: Polygon.fromPoints(points: [_polygonPoints.toList()]),
            fillColor: Colors.redAccent.value,
            fillOpacity: 0.5,
          ),
        );

        // Remove all circle annotations
        await _circleAnnotationManager!.deleteAll();
        _circleAnnotations.clear();
        _polygonPoints.clear();

        setState(() {
          _isEditing = false; // Toggle editing state off
        });
      } else {
        // Start editing mode
        setState(() {
          _isEditing = true; // Toggle editing state on
          _currentPolygon = null; // Reset polygon
        });
      }
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }

  /// Undoes the last added point and removes the corresponding circle.
  Future<void> _undoLastPoint() async {
    if (_polygonPoints.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true; // Start loading
      _polygonPoints.removeLast(); // Remove the last point
    });

    try {
      // Remove the last circle annotation
      if (_circleAnnotations.isNotEmpty) {
        final lastCircle = _circleAnnotations.removeLast();
        await _circleAnnotationManager!.delete(lastCircle);
      }

      if (_polygonPoints.length > 2) {
        // Update the polygon with the remaining points
        _currentPolygon?.geometry =
            Polygon.fromPoints(points: [_polygonPoints.toList()]);

        await _polygonAnnotationManager!.update(_currentPolygon!);
      } else {
        // If less than 3 points, remove the polygon completely
        if (_currentPolygon != null) {
          await _polygonAnnotationManager!.delete(_currentPolygon!);
          _currentPolygon = null;
        }
      }
    } finally {
      setState(() {
        _isLoading = false; // End loading
      });
    }
  }
}

final class _AnnotationClickListener extends OnPolygonAnnotationClickListener {
  @override
  void onPolygonAnnotationClick(PolygonAnnotation annotation) {
    print('Polygon clicked: $annotation');
  }
}
