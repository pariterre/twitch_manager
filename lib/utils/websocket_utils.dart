import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('WebSocketExtension');

class WebSocketUtils {
  static void safeWebsocketAdd(WebSocket socket, Object data,
      {String? target}) {
    if (socket.closeCode != null) {
      _logger.fine('Socket for $target already closed, skipping message');
      return;
    }
    try {
      socket.add(data);
    } on SocketException catch (e) {
      _logger.warning('Socket error while sending message to $target: $e');
    } catch (e, st) {
      _logger.severe('Unexpected socket error while sending to $target', e, st);
    }
  }
}
