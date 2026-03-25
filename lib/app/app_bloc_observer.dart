import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/services/error_service.dart';

class AppBlocObserver extends BlocObserver {
  static const int _windowMs = 1000;
  static const int _warnThresholdPerWindow = 30;
  static const int _warnCooldownMs = 3000;
  static const bool _verboseLogs = false;

  final Map<String, Queue<int>> _emissionTimestampsByBloc = {};
  final Map<String, int> _lastWarnAtByBloc = {};

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _trackEmission(bloc);
    _logDev('CHANGE', bloc, change: change);
  }

  @override
  void onTransition(
      Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    _logDev('TRANSITION', bloc, transition: transition);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    ErrorService.handleError(
      '[BlocError] ${bloc.runtimeType}: $error',
      stackTrace,
      sendToSentry: true,
    );
    _logDev('ERROR', bloc, error: error);
  }

  void _trackEmission(BlocBase<dynamic> bloc) {
    final blocName = bloc.runtimeType.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    final queue = _emissionTimestampsByBloc.putIfAbsent(
      blocName,
      () => Queue<int>(),
    );

    queue.addLast(now);

    final cutoff = now - _windowMs;
    while (queue.isNotEmpty && queue.first < cutoff) {
      queue.removeFirst();
    }

    if (queue.length >= _warnThresholdPerWindow) {
      final lastWarnAt = _lastWarnAtByBloc[blocName] ?? 0;
      if (now - lastWarnAt < _warnCooldownMs) {
        return;
      }
      _lastWarnAtByBloc[blocName] = now;
      debugPrint(
        '[BlocObserver] High emission rate in $blocName: '
        '${queue.length} state emissions within ${_windowMs}ms',
      );
    }
  }

  void _logDev(
    String type,
    BlocBase<dynamic> bloc, {
    Change<dynamic>? change,
    Transition<dynamic, dynamic>? transition,
    Object? error,
  }) {
    if (kReleaseMode) return;
    if (!_verboseLogs && type != 'ERROR') return;

    if (type == 'ERROR') {
      debugPrint('[BlocObserver][$type] ${bloc.runtimeType} -> $error');
      return;
    }

    if (type == 'TRANSITION' && transition != null) {
      debugPrint(
        '[BlocObserver][$type] ${bloc.runtimeType}: '
        '${transition.currentState} -> ${transition.nextState}',
      );
      return;
    }

    if (type == 'CHANGE' && change != null) {
      debugPrint(
        '[BlocObserver][$type] ${bloc.runtimeType}: '
        '${change.currentState} -> ${change.nextState}',
      );
    }
  }
}
