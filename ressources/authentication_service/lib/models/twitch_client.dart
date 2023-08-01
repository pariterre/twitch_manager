import 'dart:convert';
import 'dart:io';

String _currentProtocol = '1.0.0';

enum _Status {
  idle,
  waitingForStateToken,
  readyToSendResponse,
  failure,
  success,
}

class TwitchClient {
  int createTime; // Seconds
  final WebSocket _socket;
  bool _isConnected = false;
  int? stateToken;
  var _currentStatus = _Status.idle;
  final Function(int id, {required bool isSuccess}) onRequestTermination;

  int get id => hashCode;

  TwitchClient(this._socket, {required this.onRequestTermination})
      : createTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 {
    // Sending handshake
    _socket.add(json.encode({
      'status': _Status.waitingForStateToken.name,
      'protocolVersion': _currentProtocol,
    }));
    _currentStatus = _Status.waitingForStateToken;
    // Listening to answer
    _socket.listen(_communicateWithClient);
    _isConnected = true;
  }

  void terminateConnexion() {
    if (_isConnected) {
      _socket.close();
      _isConnected = false;
    }
  }

  bool _failIfNull(element, String message) {
    if (element != null) return false;

    _currentStatus = _Status.failure;
    return true;
  }

  void sendTwitchAnswer(String message) {
    if (_currentStatus != _Status.readyToSendResponse) {
      // This is symptomatic of failing system
      _currentStatus = _Status.failure;
      return;
    }

    _socket.add(json.encode({
      'status': _Status.readyToSendResponse.name,
      'twitchResponse': message
    }));

    _currentStatus = _Status.success;
  }

  void _communicateWithClient(message) {
    if (_currentStatus == _Status.failure) {
      return;
    }

    // Decode the message
    final map = jsonDecode(message);

    // Parse it depending on the nature of the message
    if (_currentStatus == _Status.waitingForStateToken) {
      stateToken = int.parse(map?['stateToken']);
      if (_failIfNull(stateToken, 'StateToken unavailable, droping client')) {
        return;
      }

      _currentStatus = _Status.readyToSendResponse;
      return;
    }

    if (_currentStatus == _Status.success) {
      onRequestTermination(id, isSuccess: true);
      return;
    }

    print('Unrecognized message from client');
  }
}
