Future<T> retry<T>(
  Future<T> Function() fn, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 500),
  double backoffFactor = 1.5,
  bool Function(Object error)? shouldRetry,
}) async {
  assert(attempts > 0, 'attempts must be greater than zero');
  if (attempts == 1) {
    return fn();
  }

  var currentDelay = delay;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      final canRetry = shouldRetry?.call(error) ?? true;
      if (attempt == attempts || !canRetry) {
        rethrow;
      }
      await Future<void>.delayed(currentDelay);
      currentDelay = Duration(
        milliseconds: (currentDelay.inMilliseconds * backoffFactor).round(),
      );
    }
  }

  throw StateError('unreachable retry branch');
}
