import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

class BleReconnectionCoordinator {
  BleReconnectionCoordinator({required this.platform});

  final BlePlatform platform;

  StreamSubscription<BleLinkState>? _subscription;
  bool _reconnectionInProgress = false;
  bool _abortReconnection = false;

  BleDevice? _device;
  bool Function()? _shouldIgnoreDisconnect;
  void Function()? _onLinkLost;
  Future<bool> Function(BleDevice device)? _runReconnectSessions;
  void Function()? _onReconnectSucceeded;
  void Function(bool success)? _onReconnectEpisodeEnded;
  Future<void> Function(BleDevice device, Object error)? _onListenerError;

  void attach(
    BleDevice device, {
    required bool Function() shouldIgnoreDisconnect,
    required void Function() onLinkLost,
    required Future<bool> Function(BleDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
    required void Function(bool success) onReconnectEpisodeEnded,
    required Future<void> Function(BleDevice device, Object error)
        onListenerError,
  }) {
    detach();
    reset();

    _device = device;
    _shouldIgnoreDisconnect = shouldIgnoreDisconnect;
    _onLinkLost = onLinkLost;
    _runReconnectSessions = runReconnectSessions;
    _onReconnectSucceeded = onReconnectSucceeded;
    _onReconnectEpisodeEnded = onReconnectEpisodeEnded;
    _onListenerError = onListenerError;

    _subscription = platform.connectionState(device.id).listen((state) async {
      try {
        if (state == BleLinkState.disconnected) {
          debugPrint(
            '[BLE][coordinator] link=disconnected '
            'ignore=${shouldIgnoreDisconnect()} '
            'inProgress=$_reconnectionInProgress abort=$_abortReconnection',
          );
        }
        if (state == BleLinkState.disconnected &&
            !shouldIgnoreDisconnect() &&
            !_reconnectionInProgress) {
          await _startReconnectionEpisode(device);
        }
      } catch (_) {}
    });

    _subscription?.onError((error) {
      final handler = _onListenerError;
      if (handler != null) {
        unawaited(handler(device, error));
      }
    });
  }

  bool canStartReconnectionEpisode() {
    return !_reconnectionInProgress && !_abortReconnection;
  }

  bool shouldCancelReconnectWork() {
    return _abortReconnection;
  }

  void abortCurrentEpisode() {
    _abortReconnection = true;
  }

  Future<void> notifyUnexpectedLinkLost() async {
    final device = _device;
    if (device == null || _subscription == null) {
      return;
    }
    if (!canStartReconnectionEpisode()) {
      return;
    }
    if (_shouldIgnoreDisconnect?.call() ?? true) {
      return;
    }
    await _startReconnectionEpisode(device);
  }

  Future<void> _startReconnectionEpisode(BleDevice device) async {
    _onLinkLost?.call();
    await _runReconnectionEpisode(
      device,
      runReconnectSessions: _runReconnectSessions!,
      onReconnectSucceeded: _onReconnectSucceeded!,
    );
  }

  void cancelReconnection() {
    abortCurrentEpisode();
    detach();
    _reconnectionInProgress = false;
  }

  Future<void> _runReconnectionEpisode(
    BleDevice device, {
    required Future<bool> Function(BleDevice device) runReconnectSessions,
    required void Function() onReconnectSucceeded,
  }) async {
    if (_abortReconnection) {
      return;
    }

    _reconnectionInProgress = true;

    var success = false;
    try {
      if (_abortReconnection) {
        return;
      }
      success = await runReconnectSessions(device);
      if (_abortReconnection) {
        success = false;
      }
      if (success) {
        onReconnectSucceeded();
      }
    } finally {
      _onReconnectEpisodeEnded?.call(success);
      reset();
    }
  }

  void detach() {
    _subscription?.cancel();
    _subscription = null;
    _device = null;
    _shouldIgnoreDisconnect = null;
    _onLinkLost = null;
    _runReconnectSessions = null;
    _onReconnectSucceeded = null;
    _onReconnectEpisodeEnded = null;
    _onListenerError = null;
  }

  void reset() {
    _reconnectionInProgress = false;
    _abortReconnection = false;
  }
}
