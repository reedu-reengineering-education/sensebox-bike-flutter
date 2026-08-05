import 'package:sensebox_bike/services/error_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchExternalUrl(
  String url, {
  required Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFunction,
}) async {
  try {
    await launchUrlFunction(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (error, stack) {
    ErrorService.handleError(error, stack);
  }
}
