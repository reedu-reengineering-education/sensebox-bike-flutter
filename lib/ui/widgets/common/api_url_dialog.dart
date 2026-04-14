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
    final tranlsations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final apiUrls = widget.apiUrls;
    final isLoading = widget.isLoading;
    final error = widget.error;
    final controller = widget.controller;
    final settingsBloc = widget.settingsBloc;
    String? dropdownValue = (apiUrls != null && apiUrls.contains(selectedUrl)) ? selectedUrl : null;

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 24.0),
      content: SizedBox(
        width: 320,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tranlsations.settingsApiUrl,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const CircularProgressIndicator()
              else if (error != null)
                Column(
                  children: [
                    Icon(Icons.cloud_off,
                        color: theme.colorScheme.error, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      tranlsations.settingsApiUrlLoadError,
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
                          style: TextStyle(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tranlsations.generalClose),
                      ),
                    ),
                  ],
                )
              else if (apiUrls != null && apiUrls.isNotEmpty)
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      DropdownButtonFormField<String>(
                          initialValue: dropdownValue,
                          decoration: InputDecoration(
                            labelText: tranlsations.settingsApiUrl,
                          ),
                          items: apiUrls
                              .map((url) => DropdownMenuItem<String>(
                                    value: url,
                                    child: Tooltip(
                                      message: url,
                                      child: SizedBox(
                                        width: 220, // Adjust width as needed
                                        child: Text(
                                          url,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedUrl = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(tranlsations.generalCancel),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: selectedUrl == null || selectedUrl == settingsBloc.apiUrl
                                  ? null
                                  : () async {
                                      await settingsBloc.setApiUrl(selectedUrl!);
                                      Navigator.of(context).pop();
                                    },
                              child: Text(tranlsations.generalSave),
                            ),
                        ],
                      ),
                    ],
                  ),
                )
              else ...[
                ApiUrlField(
                  controller: controller,
                  helperText: tranlsations.settingsApiUrlHelper,
                  defaultValue: standardOpenSenseMapApiUrl,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tranlsations.generalCancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(tranlsations.generalSave),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
