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
  static const _kCustomUrl = '__custom__';

  final formKey = GlobalKey<FormState>();
  String? _dropdownValue;

  @override
  void initState() {
    super.initState();
    _initDropdownValue();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ApiUrlDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiUrls != widget.apiUrls) {
      setState(_initDropdownValue);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _initDropdownValue() {
    final currentUrl = widget.settingsBloc.apiUrl;
    final apiUrls = widget.apiUrls;
    if (apiUrls == null) return;
    if (apiUrls.contains(currentUrl)) {
      _dropdownValue = currentUrl;
    } else if (currentUrl.isNotEmpty) {
      _dropdownValue = _kCustomUrl;
      if (widget.controller.text.isEmpty) {
        widget.controller.text = currentUrl;
      }
    }
  }

  void _onControllerChanged() => setState(() {});

  bool get _isSaveDisabled {
    if (_dropdownValue == null) return true;
    if (_dropdownValue == _kCustomUrl) {
      final text = widget.controller.text;
      return text.isEmpty || text == widget.settingsBloc.apiUrl;
    }
    return _dropdownValue == widget.settingsBloc.apiUrl;
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

    Widget content;
    List<Widget> actions;

    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
      actions = [];
    } else if (error != null) {
      content = SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 8),
            Text(
              translations.settingsApiUrlLoadErrorDetails,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  translations.settingsApiUrlEditManually,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onExpansionChanged: (_) => setState(() {}),
                children: [
                  if (error.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        translations.generalError,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      translations.settingsApiUrlEditManuallyHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Form(
                    key: formKey,
                    child: ApiUrlField(
                      controller: controller,
                      helperText: translations.settingsApiUrlHelper,
                      defaultValue: standardOpenSenseMapApiUrl,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      );
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translations.generalCancel),
        ),
        FilledButton(
          onPressed:
              controller.text.isEmpty || controller.text == settingsBloc.apiUrl
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        await settingsBloc.setApiUrl(controller.text);
                        Navigator.of(context).pop();
                      }
                    },
          child: Text(translations.generalSave),
        ),
      ];
    } else if (apiUrls != null && apiUrls.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _dropdownValue,
            isExpanded: true,
            decoration: InputDecoration(labelText: translations.settingsApiUrl),
            selectedItemBuilder: (context) => [
              ...apiUrls.map((url) => Text(
                    url,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )),
              Text(translations.settingsApiUrlCustomOption),
            ],
            items: [
              ...apiUrls.map((url) => DropdownMenuItem<String>(
                    value: url,
                    child: Tooltip(
                      message: url,
                      child: Text(
                        url,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  )),
              DropdownMenuItem<String>(
                value: _kCustomUrl,
                child: Text(translations.settingsApiUrlCustomOption),
              ),
            ],
            onChanged: (value) => setState(() {
              _dropdownValue = value;
              if (value != _kCustomUrl) controller.clear();
            }),
          ),
          if (_dropdownValue == _kCustomUrl) ...[
            const SizedBox(height: 8),
            Form(
              key: formKey,
              child: ApiUrlField(
                controller: controller,
                helperText: translations.settingsApiUrlHelper,
                defaultValue: standardOpenSenseMapApiUrl,
              ),
            ),
          ],
        ],
      );
      actions = [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translations.generalCancel),
        ),
        FilledButton(
          onPressed: _isSaveDisabled
              ? null
              : () async {
                  if (_dropdownValue == _kCustomUrl) {
                    if (!formKey.currentState!.validate()) return;
                    await settingsBloc.setApiUrl(controller.text);
                  } else {
                    await settingsBloc.setApiUrl(_dropdownValue!);
                  }
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
      scrollable: true,
    );
  }
}
