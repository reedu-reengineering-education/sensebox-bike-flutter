import 'package:flutter/material.dart';

class CheckboxWithText extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String text;
  final Offset offset; 

  const CheckboxWithText({
    super.key,
    required this.value,
    required this.onChanged,
    required this.text,
    this.offset = const Offset(0, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset, 
      child: Row(
        children: [
          Checkbox(value: value,onChanged: onChanged),
          Text(text),
        ],
      ),
    );
  }
}