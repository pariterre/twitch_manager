import 'dart:async';

import 'package:logging/logging.dart';

final _logger = Logger('Completers');

class Completers<T> {
  final Map<int, Completer<T>> _completers = {};

  int spawn() {
    final completer = Completer<T>();
    // Create a unique id for the completer based on salted hashcode
    final id = _completers.hashCode + DateTime.now().hashCode;
    _completers[id] = completer;

    completer.future
        .then((_) => _completers.remove(id))
        .onError((_, __) => _completers.remove(id));
    return id;
  }

  Completer<T>? get(int id) => _completers[id];

  void complete(int id, {required T data}) {
    try {
      final completer = _completers[id]!;
      completer.complete(data);
    } catch (e) {
      _logger.severe('Error while completing completer: $e');
    }
  }
}
