import 'package:flutter/material.dart';

class LabeledTextFormField extends FormField<String> {
  LabeledTextFormField({
    super.key,
    required String labelText,
    String? initialValue,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    TextInputType? keyboardType,
    List<String>? autofillHints,
  }) : super(
          initialValue: initialValue,
          validator: validator,
          onSaved: onSaved,
          builder: (FormFieldState<String> state) {
            return _LabeledTextFormFieldStateful(
              labelText: labelText,
              enabled: enabled,
              state: state,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
            );
          },
        );
}

class _LabeledTextFormFieldStateful extends StatefulWidget {
  final String labelText;
  final bool enabled;
  final FormFieldState<String> state;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;

  const _LabeledTextFormFieldStateful({
    required this.labelText,
    required this.enabled,
    required this.state,
    this.keyboardType,
    this.autofillHints,
  });

  @override
  State<_LabeledTextFormFieldStateful> createState() =>
      __LabeledTextFormFieldStatefulState();
}

class __LabeledTextFormFieldStatefulState
    extends State<_LabeledTextFormFieldStateful> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.value);
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(_LabeledTextFormFieldStateful oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.value != widget.state.value &&
        _controller.text != widget.state.value) {
      _controller.text = widget.state.value ?? '';
    }
  }

  void _onChanged() {
    widget.state.didChange(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: widget.state.errorText,
      ),
      onChanged: (value) {
        widget.state.didChange(value);
      },
    );
  }
}

