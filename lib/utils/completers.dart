import 'dart:async';

class Completers {
  final Map<int, Completer> _completers = {};

  int spawn() {
    final completer = Completer();
    // Create a unique id for the completer based on salted hashcode
    final id = _completers.hashCode + DateTime.now().hashCode;
    _completers[id] = completer;

    completer.future
        .then((_) => _completers.remove(id))
        .onError((_, __) => _completers.remove(id));
    return id;
  }

  Completer? get(int id) => _completers[id];

  void complete(int id, {required dynamic data}) {
    final completer = _completers[id]!;
    completer.complete(data);
  }
}
