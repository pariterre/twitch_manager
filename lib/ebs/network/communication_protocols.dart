import 'dart:convert';

import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_public_objects.dart';

enum MessageFrom {
  app,
  ebsMain,
  ebsIsolated,
  frontend,
  generic;
}

enum MessageTo {
  app,
  ebsMain,
  ebsIsolated,
  frontend,
  pubsub,
  generic;
}

enum MessageTypes {
  handShake,
  ping,
  pong,
  get,
  put,
  bitTransaction,
  response,
  disconnect;
}

class MessageProtocol {
  final MessageFrom from;
  final MessageTo to;
  final MessageTypes type;

  final Map<String, dynamic>? data;
  final BitsTransactionObject? transaction;

  final bool? isSuccess;
  final Map<String, dynamic>? internalMain;
  final Map<String, dynamic>? internalIsolate;
  final Map<String, dynamic>? internalClient;
  final Map<String, dynamic>? internalFrontend;

  MessageProtocol({
    required this.from,
    required this.to,
    required this.type,
    this.data,
    this.transaction,
    this.isSuccess,
    this.internalMain,
    this.internalIsolate,
    this.internalClient,
    this.internalFrontend,
  });

  Map<String, dynamic> toJson() => {
        'from': from.index,
        'to': to.index,
        'type': type.index,
        'data': data,
        'transaction': transaction?.toJson(),
        'is_success': isSuccess,
        'internal_main': internalMain,
        'internal_isolate': internalIsolate,
        'internal_client': internalClient,
        'internal_frontend': internalFrontend,
      };
  String encode() => jsonEncode(toJson());

  factory MessageProtocol.fromJson(Map<String, dynamic> json) {
    return MessageProtocol(
      from: MessageFrom.values[json['from']],
      to: MessageTo.values[json['to']],
      type: MessageTypes.values[json['type']],
      data: json['data'],
      transaction: json['transaction'] != null
          ? BitsTransactionObject.fromJson(json['transaction'])
          : null,
      isSuccess: json['is_success'],
      internalMain: json['internal_main'],
      internalIsolate: json['internal_isolate'],
      internalClient: json['internal_client'],
      internalFrontend: json['internal_frontend'],
    );
  }

  factory MessageProtocol.decode(String raw) {
    return MessageProtocol.fromJson(jsonDecode(raw));
  }

  MessageProtocol copyWith({
    required MessageFrom from,
    required MessageTo to,
    required MessageTypes type,
    Map<String, dynamic>? data,
    BitsTransactionObject? transaction,
    bool? isSuccess,
    Map<String, dynamic>? internalMain,
    Map<String, dynamic>? internalIsolate,
    Map<String, dynamic>? internalClient,
    Map<String, dynamic>? internalFrontend,
  }) =>
      MessageProtocol(
        from: from,
        to: to,
        type: type,
        data: data ??= this.data,
        transaction: transaction ??= this.transaction,
        isSuccess: isSuccess ??= this.isSuccess,
        internalMain: internalMain ??= this.internalMain,
        internalIsolate: internalIsolate ??= this.internalIsolate,
        internalClient: internalClient ??= this.internalClient,
        internalFrontend: internalFrontend ??= this.internalFrontend,
      );
}
