import 'package:flutter/material.dart';

class ImageSelectFormField<T> extends FormField<T> {
  ImageSelectFormField({
    super.key,
    required List<ImageSelectItem> items,
    required ImageSelectController controller,
    super.onSaved,
    super.validator,
    T? initialValue,
    bool autovalidate = false,
    required String label,
  }) : super(
          initialValue: controller.selectedValue,
          autovalidateMode: autovalidate
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          builder: (FormFieldState<T> state) {
            BuildContext context = state.context;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 12),
                Row(
                  children: items.map((item) {
                    bool isSelected = controller.selectedValue == item.value;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          controller.select(item.value);
                          state.didChange(
                              item.value); // Update the form field state
                        },
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: isSelected ? 2 : 0,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                item.imagePath,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(height: 12),
                              Text(item.label),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      state.errorText ?? '',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );
}

class ImageSelectItem<T> {
  final T value;
  final String label;
  final String imagePath;

  ImageSelectItem({
    required this.value,
    required this.label,
    required this.imagePath,
  });
}

class ImageSelectController<T> extends ValueNotifier<T?> {
  ImageSelectController({T? initialValue}) : super(initialValue);

  // Getter to retrieve the current selected value
  T? get selectedValue => value;

  // Method to set the selected value
  void select(T newValue) {
    value = newValue;
  }
}
