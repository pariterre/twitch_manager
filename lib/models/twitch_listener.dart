class TwitchGenericListener<T extends Function> {
  ///
  /// Start listening.
  void startListening(T callback) => _listeners.add(callback);

  ///
  /// Stop listening.
  void stopListening(T callback) => _listeners.remove(callback);

  ///
  /// Stop all listeners.
  void clearListeners() => _listeners.clear();

  ///
  /// Notify all listeners.
  void notifyListeners(void Function(T) callback) =>
      _listeners.forEach(callback);

  ///
  /// List of active listeners to notify.
  final List<T> _listeners = [];
}
