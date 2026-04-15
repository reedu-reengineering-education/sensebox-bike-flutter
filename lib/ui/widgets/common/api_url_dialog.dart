import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/settings_bloc.dart';
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/ui/widgets/common/api_url_field.dart';

class ApiUrlDialog extends StatefulWidget {
  final SettingsBloc settingsBloc;
  final TextEditingController controller;
  final List<String>? apiUrls;
  final bool isLoading;
  final String? error;
  final void Function(void Function())? setState;

  const ApiUrlDialog({
    super.key,
    required this.settingsBloc,
    required this.controller,
    this.apiUrls,
    this.isLoading = false,
    this.error,
    this.setState,
  });

  @override
  State<ApiUrlDialog> createState() => _ApiUrlDialogState();
}

class _ApiUrlDialogState extends State<ApiUrlDialog> {
  final formKey = GlobalKey<FormState>();
  String? selectedUrl;

  @override
  void initState() {
    super.initState();
    selectedUrl = widget.settingsBloc.apiUrl;
  }

  @override
  Widget build(BuildContext context) {
    final translations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final apiUrls = widget.apiUrls;
    final isLoading = widget.isLoading;
    final error = widget.error;
    final controller = widget.controller;
    final settingsBloc = widget.settingsBloc;
    final dropdownValue =
        (apiUrls != null && apiUrls.contains(selectedUrl)) ? selectedUrl : null;

    Widget content;
    List<Widget> actions;

    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
      actions = [];
    } else if (error != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: theme.colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text(
            translations.settingsApiUrlLoadError,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translations.generalClose),
        ),
      ];
    } else if (apiUrls != null && apiUrls.isNotEmpty) {
      content = DropdownButtonFormField<String>(
        value: dropdownValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: translations.settingsApiUrl),
        selectedItemBuilder: (context) => apiUrls
            .map((url) => Text(
                  url,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ))
            .toList(),
        items: apiUrls
            .map((url) => DropdownMenuItem<String>(
                  value: url,
                  child: Tooltip(
                    message: url,
                    child: Text(
                      url,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ))
            .toList(),
        onChanged: (value) => setState(() => selectedUrl = value),
      );
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translations.generalCancel),
        ),
        FilledButton(
          onPressed: selectedUrl == null || selectedUrl == settingsBloc.apiUrl
              ? null
              : () async {
                  await settingsBloc.setApiUrl(selectedUrl!);
                  Navigator.of(context).pop();
                },
          child: Text(translations.generalSave),
        ),
      ];
    } else {
      content = Form(
        key: formKey,
        child: ApiUrlField(
          controller: controller,
          helperText: translations.settingsApiUrlHelper,
          defaultValue: standardOpenSenseMapApiUrl,
        ),
      );
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translations.generalCancel),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              formKey.currentState!.save();
              Navigator.of(context).pop();
            }
          },
          child: Text(translations.generalSave),
        ),
      ];
    }

    return AlertDialog(
      title: Text(translations.settingsApiUrl),
      content: content,
      actions: actions,
    );
  }
}
