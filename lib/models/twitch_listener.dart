class TwitchGenericListener<T extends Function> {
  ///
  /// Start listening.
  void add(T callback) {
    _listeners.add(callback);
  }

  ///
  /// Stop listening.
  void remove(T callback) {
    _listeners.remove(callback);
  }

  ///
  /// Stop all listeners.
  void disposeAll() {
    _listeners.clear();
  }

  ///
  /// Notify all listeners.
  void forEach(void Function(T) callback) {
    _listeners.forEach(callback);
  }

  ///
  /// List of active listeners to notify.
  final List<T> _listeners = [];
}
