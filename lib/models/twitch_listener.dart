class TwitchGenericListener<T extends Function> {
  ///
  /// Start listening.
  void add(String id, T callback) {
    listeners[id] = callback;
  }

  ///
  /// Stop listening.
  void dispose(String id) {
    listeners.remove(id);
  }

  ///
  /// Stop all listeners.
  void disposeAll() {
    listeners.clear();
  }

  ///
  /// List of active listeners to notify.
  final Map<String, T> listeners = {};

  TwitchGenericListener();
}
