import 'package:flutter/material.dart';

class SensorConditionalRerender extends StatefulWidget {
  final Stream<List<double>> valueStream;
  final List<double> initialValue;
  final List<double> latestValue;
  final Widget Function(BuildContext, List<double>) builder;
  final int decimalPlaces;
  const SensorConditionalRerender({
    required this.valueStream,
    required this.initialValue,
    required this.latestValue,
    required this.builder,
    this.decimalPlaces = 1,
    Key? key,
  }) : super(key: key);

  @override
  State<SensorConditionalRerender> createState() => _SensorConditionalRerenderState();
}

class _SensorConditionalRerenderState extends State<SensorConditionalRerender> {
  List<double> _lastValue = [];
  Widget? _cachedWidget;

  @override
  void initState() {
    super.initState();
    _lastValue = List<double>.from(widget.initialValue);
    _cachedWidget = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<double>>(
      stream: widget.valueStream,
      initialData: widget.initialValue,
      builder: (context, snapshot) {
        final data = snapshot.data ?? widget.initialValue;
        if (_round(widget.latestValue[0]) == _round(data[0]) && _cachedWidget != null) {
          return _cachedWidget!;
        } else {
          _lastValue = List<double>.from(data);
          _cachedWidget = widget.builder(context, data);
          return _cachedWidget!;
        }
      },
    );
  }

  double _round(double v) => double.parse(v.toStringAsFixed(widget.decimalPlaces));
} 