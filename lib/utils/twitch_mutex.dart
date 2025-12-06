class TwitchMutex<T> {
  bool _locked = false;
  Duration duration;
  Duration timeout;

  TwitchMutex(
      {this.duration = const Duration(milliseconds: 100),
      this.timeout = const Duration(seconds: 5)});

  Future<T> runGuarded(Future<T> Function() action) async {
    final endTime = DateTime.now().add(timeout);
    while (_locked) {
      if (DateTime.now().isAfter(endTime)) {
        throw Exception('Timeout while waiting for the mutex');
      }
      await Future.delayed(duration);
    }
    _locked = true;
    try {
      return await action();
    } finally {
      _locked = false;
    }
  }
}
