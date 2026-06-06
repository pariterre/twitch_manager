import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('WebSocketExtension');

extension WebSocketExtension on WebSocket {
  void safeAdd(Object data, {String? target}) {
    if (closeCode != null) {
      _logger.fine('Socket for $target already closed, skipping message');
      return;
    }
    try {
      add(data);
    } on SocketException catch (e) {
      _logger.warning('Socket error while sending message to $target: $e');
    } catch (e, st) {
      _logger.severe('Unexpected socket error while sending to $target', e, st);
    }
  }
}
