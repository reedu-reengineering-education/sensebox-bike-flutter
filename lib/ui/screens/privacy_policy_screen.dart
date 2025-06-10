import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // For translations
import 'package:sensebox_bike/constants.dart';
import 'package:sensebox_bike/theme.dart';
import 'package:sensebox_bike/ui/screens/app_home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  _PrivacyPolicyScreenState createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _isCheckboxChecked = false;
  bool _hasScrolledToBottom = false;
  bool _isLoading = true;
  late final WebViewController _controller;

  Future<void> _saveAcceptanceDate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    await prefs.setString(SharedPreferencesKeys.privacyPolicyAcceptedAt, now);
  }

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ScrollHandler',
        onMessageReceived: (message) {
          if (message.message == 'scrolledToBottom') {
            setState(() {
              _hasScrolledToBottom = true;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            await _injectJavaScript();
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(senseBoxBikePrivacyPolicyUrl));
  }

  Future<void> _injectJavaScript() async {
    await _controller.runJavaScript('''
      (function() {
        // On the website page content is placed inside the following containers
        const containerStart = document.body.innerHTML.indexOf('<!-- <div class="container-fluid"> -->');
        const containerEnd = document.body.innerHTML.indexOf('<!-- </div> -->', containerStart);
        if (containerStart !== -1 && containerEnd !== -1) {
          const extractedContent = document.body.innerHTML.substring(containerStart, containerEnd);
          document.body.innerHTML = extractedContent; 
        }

        const sendMessageToFlutter = function(message) {
          ScrollHandler.postMessage(message);
        };

        window.onscroll = function() {
          const scrollPosition = window.scrollY || document.documentElement.scrollTop;
          const maxScroll = document.documentElement.scrollHeight - document.documentElement.clientHeight;
          if (scrollPosition >= maxScroll - 10) {
            sendMessageToFlutter('scrolledToBottom');
          }
        };
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(title: Text(localizations.settingsPrivacyPolicy)),
      body: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: spacing * 2, horizontal: spacing),
          child: Column(
            children: [
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                Expanded(child: WebViewWidget(controller: _controller)),
              Padding(
                padding: const EdgeInsets.all(spacing),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isCheckboxChecked,
                          onChanged: (value) {
                            setState(() {
                              _isCheckboxChecked = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(localizations.privacyPolicyAccept),
                        ),
                      ],
                    ),
                    const SizedBox(height: spacing),
                    FilledButton(
                      onPressed: (_isCheckboxChecked && _hasScrolledToBottom)
                          ? () async {
                              await _saveAcceptanceDate();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const AppHome()),
                              );
                            }
                          : null,
                      child: Text(localizations.generalProceed),
                    ),
                  ],
                ),
          ),
        ],
      ),
    ));
  }
}