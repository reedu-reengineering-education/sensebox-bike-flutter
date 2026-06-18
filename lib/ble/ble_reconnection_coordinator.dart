import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensebox_bike/ble/ble_device.dart';
import 'package:sensebox_bike/ble/ble_platform.dart';

/// Watches connection state and runs reconnect attempts after unexpected disconnects.
class BleReconnectionCoordinator {
  BleReconnectionCoordinator({
    required this.platform,
    required this.isReconnectingNotifier,
  });

  final BlePlatform platform;
  final ValueNotifier<bool> isReconnectingNotifier;

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
    reset(keepNotifier: true);

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
      } catch (_) {
        // Let the reconnection process handle errors.
      }
    });

    _subscription?.onError((error) {
      final handler = _onListenerError;
      if (handler != null) {
        unawaited(handler(device, error));
      }
    });
  }

  bool get shouldAbortReconnection => _abortReconnection;

  bool get isReconnectionInProgress => _reconnectionInProgress;

  /// Stops the in-flight reconnect loop without detaching the link listener.
  void abortCurrentEpisode() {
    _abortReconnection = true;
  }

  /// Used when the adapter powers off and the link-state stream may not emit.
  Future<void> notifyUnexpectedLinkLost() async {
    final device = _device;
    if (device == null || _subscription == null) {
      return;
    }
    if (_reconnectionInProgress || _abortReconnection) {
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
    detach();
    reset();
    // Set the abort latch after reset() (which clears it) so the currently
    // running episode bails out via the guard, while a future link-loss event
    // starts a fresh episode.
    _abortReconnection = true;
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
    isReconnectingNotifier.value = true;

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

  void reset({bool keepNotifier = false}) {
    _reconnectionInProgress = false;
    // Clear the abort latch so a cancelled cycle cannot permanently suppress
    // reconnection for the next unexpected disconnect. The coordinator stays
    // attached across cycles, so this latch must not survive a completed or
    // reset episode.
    _abortReconnection = false;
    if (!keepNotifier) {
      isReconnectingNotifier.value = false;
    }
  }
}
