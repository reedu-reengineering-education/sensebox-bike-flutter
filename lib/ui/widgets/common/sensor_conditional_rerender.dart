import 'package:flutter/material.dart';

class SensorConditionalRerender extends StatefulWidget {
  final Stream<List<double>> valueStream;
  final List<double> initialValue;
  final List<double> latestValue;
  final Widget Function(BuildContext, List<double>) builder;
  final int decimalPlaces;
  final bool Function(List<double> old, List<double> next)? shouldRerender;
  const SensorConditionalRerender({
    required this.valueStream,
    required this.initialValue,
    required this.latestValue,
    required this.builder,
    this.decimalPlaces = 1,
    this.shouldRerender,
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
        final defaultResult =
            _defaultShouldRerender(_lastValue, data, widget.decimalPlaces);
        final shouldSkip = widget.shouldRerender != null
            ? !widget.shouldRerender!(_lastValue, data)
            : !defaultResult;
  
        if (shouldSkip && _cachedWidget != null) {
          return _cachedWidget!;
        } else {
          _lastValue = List<double>.from(data);
          _cachedWidget = widget.builder(context, data);
          return _cachedWidget!;
        }
      },
    );
  }

  bool _defaultShouldRerender(
      List<double> old, List<double> next, int decimalPlaces) {
    if (old.length != next.length) return true;
    for (int i = 0; i < old.length; i++) {
      if (_round(old[i], decimalPlaces) != _round(next[i], decimalPlaces)) {
        return true;
      }
    }
    return false;
  }

  double _round(double v, int decimalPlaces) =>
      double.parse(v.toStringAsFixed(decimalPlaces));
} 