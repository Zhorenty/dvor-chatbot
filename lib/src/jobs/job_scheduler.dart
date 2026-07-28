import 'dart:async';

import 'package:l/l.dart';

/// Runs tracked background work with per-name in-flight guards.
final class JobScheduler {
  JobScheduler({
    void Function(int activeOperations)? onActiveOperationsChanged,
  }) : _onActiveOperationsChanged = onActiveOperationsChanged;

  final void Function(int activeOperations)? _onActiveOperationsChanged;
  final Map<String, bool> _inFlight = <String, bool>{};
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;

  int get activeOperations => _activeOperations;

  bool isInFlight(String name) => _inFlight[name] == true;

  /// Launches [action] unless another run of [name] is already in flight.
  void launch(String name, Future<void> Function() action) {
    if (_inFlight[name] == true) {
      l.i('Skipping background $name job: previous run still in flight');
      return;
    }
    _inFlight[name] = true;
    unawaited(
      _runTracked(action).whenComplete(() {
        _inFlight[name] = false;
      }).onError<Object>((error, stackTrace) {
        l.w('Background $name job failed: $error', stackTrace);
      }),
    );
  }

  Future<T> runTracked<T>(Future<T> Function() action) => _runTracked(action);

  Future<T> _runTracked<T>(Future<T> Function() action) async {
    _activeOperations += 1;
    _onActiveOperationsChanged?.call(_activeOperations);
    try {
      return await action();
    } finally {
      _activeOperations -= 1;
      _onActiveOperationsChanged?.call(_activeOperations);
      if (_activeOperations == 0) {
        _idleCompleter?.complete();
        _idleCompleter = null;
      }
    }
  }

  Future<void> waitForIdle({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_activeOperations == 0) {
      return;
    }
    final completer = _idleCompleter ??= Completer<void>();
    await completer.future.timeout(
      timeout,
      onTimeout: () {
        l.w(
          'Timed out after ${timeout.inSeconds}s waiting for '
          '$_activeOperations active operation(s); proceeding with shutdown.',
        );
      },
    );
  }
}
