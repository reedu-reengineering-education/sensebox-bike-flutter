import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';

class UploadErrorClassifier {
  static bool isAuthError(Object? error) =>
      error is PermanentAuthenticationError || error is AuthException;

  static bool isConnectionError(Object? error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is HttpException ||
      error is HandshakeException ||
      error is http.ClientException;

  static UploadFailureKind failureKindOf(Object? error) {
    if (isAuthError(error)) return UploadFailureKind.authentication;
    if (isConnectionError(error)) return UploadFailureKind.connection;
    if (error is TooManyRequestsException ||
        error is ServerErrorException ||
        error is OpenSenseMapApiException) {
      return UploadFailureKind.apiResponse;
    }
    return UploadFailureKind.other;
  }

  static String describe(Object? error) {
    if (error is TimeoutException) {
      final seconds = error.duration?.inSeconds;
      return seconds != null
          ? 'No response within $seconds s'
          : 'No response (timeout)';
    }
    if (error is SocketException) {
      final osMessage = error.osError?.message;
      return _cleanNetworkMessage(osMessage != null && osMessage.isNotEmpty
          ? '${error.message} ($osMessage)'
          : error.message);
    }
    if (error is http.ClientException) {
      return _cleanNetworkMessage(error.message);
    }
    if (error is HttpException) {
      return _cleanNetworkMessage(error.message);
    }
    if (error is HandshakeException) {
      return _cleanNetworkMessage('Secure connection failed: ${error.message}');
    }
    if (error is TooManyRequestsException) {
      return 'HTTP 429: Too many requests';
    }
    if (error is ServerErrorException) {
      return _withApiMessage('HTTP ${error.statusCode}', error.body);
    }
    if (error is OpenSenseMapApiException) {
      return _withApiMessage('HTTP ${error.statusCode}', error.body);
    }
    return error?.toString() ?? '';
  }

  static String _cleanNetworkMessage(String message) {
    return message
        .replaceFirst(
            RegExp(r'^(SocketException|HttpException|HandshakeException):\s*'),
            '')
        .replaceAll('OS Error: ', '')
        .replaceAll(RegExp(r',\s*errno = \d+'), '')
        .trim();
  }

  static String _withApiMessage(String prefix, String? body) {
    final message = _extractApiMessage(body);
    return message == null ? prefix : '$prefix: $message';
  }

  static String? _extractApiMessage(String? body) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final key in const ['message', 'error', 'code']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    if (trimmed.startsWith('<')) return null;
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }
}
