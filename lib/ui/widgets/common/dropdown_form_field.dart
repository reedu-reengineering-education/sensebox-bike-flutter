import 'package:flutter/material.dart';

class DropdownFormField<T> extends FormField<T> {
  DropdownFormField({
    super.key,
    required String labelText,
    required List<DropdownItem<T>> items,
    super.initialValue,
    bool enabled = true,
    super.validator,
    super.onSaved,
    String? disabledHint,
    Widget? Function(BuildContext, T)? itemBuilder,
  }) : super(
          builder: (FormFieldState<T> state) {
            return DropdownButtonFormField<T>(
              initialValue: state.value,
              decoration: InputDecoration(
                labelText: labelText,
                errorText: state.errorText,
              ),
              items: items.map((item) {
                Widget child;
                if (itemBuilder != null && item.value != null) {
                  final built = itemBuilder(state.context, item.value!);
                  child = built ?? Text(item.label);
                } else {
                  child = Text(item.label);
                }
                return DropdownMenuItem<T>(
                  value: item.value,
                  child: child,
                );
              }).toList(),
              onChanged: enabled
                  ? (T? value) {
                      state.didChange(value);
                    }
                  : null,
              disabledHint: disabledHint != null
                  ? Text(disabledHint)
                  : null,
            );
          },
        );
}

class DropdownItem<T> {
  final T? value;
  final String label;

  DropdownItem({
    required this.value,
    required this.label,
  });
}

