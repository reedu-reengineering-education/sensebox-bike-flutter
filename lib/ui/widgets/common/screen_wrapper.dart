import 'package:flutter/material.dart';
import 'package:sensebox_bike/ui/layout/content_constraint.dart';

class ScreenWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final double padding;

  /// When true (default), constrains body width on tablet. Phone unchanged.
  final bool constrainContent;

  const ScreenWrapper({
    super.key,
    required this.child,
    this.title,
    this.padding = 0,
    this.constrainContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.all(padding),
      child: child,
    );

    return Scaffold(
      appBar: AppBar(title: Text(title ?? '')),
      body: constrainContent ? ContentConstraint(child: body) : body,
    );
  }
}
