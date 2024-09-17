abstract class ProtocolException implements Exception {}

class InvalidTargetException implements ProtocolException {
  @override
  String toString() => 'Invalid target';
}

abstract class NetworkException implements Exception {}

class NoBroadcasterIdException implements NetworkException {
  @override
  String toString() => 'BroadcasterId not found';
}

class UnauthorizedException implements Exception {
  UnauthorizedException();

  @override
  String toString() {
    return 'Token verification failed';
  }
}

class InvalidEndpointException implements Exception {
  InvalidEndpointException();

  @override
  String toString() {
    return 'Invalid endpoint';
  }
}

class ConnexionToWebSocketdRefusedException implements Exception {
  ConnexionToWebSocketdRefusedException();

  @override
  String toString() {
    return 'Connexion to WebSocketd refused';
  }
}
