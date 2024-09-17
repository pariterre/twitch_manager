import 'dart:convert';

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
  generic;
}

enum MessageTypes {
  handShake,
  ping,
  pong,
  get,
  put,
  response,
  disconnect;
}

class MessageProtocol {
  final MessageFrom from;
  final MessageTo to;
  final MessageTypes type;

  final Map<String, dynamic>? data;

  final bool? isSuccess;
  final Map<String, dynamic>? internalMain;
  final Map<String, dynamic>? internalIsolate;
  final Map<String, dynamic>? internalClient;

  MessageProtocol({
    required this.from,
    required this.to,
    required this.type,
    this.data,
    this.isSuccess,
    this.internalMain,
    this.internalIsolate,
    this.internalClient,
  });

  Map<String, dynamic> toJson() => {
        'from': from.index,
        'to': to.index,
        'type': type.index,
        'data': data,
        'is_success': isSuccess,
        'internal_main': internalMain,
        'internal_isolate': internalIsolate,
        'internal_client': internalClient,
      };
  String encode() => jsonEncode(toJson());

  factory MessageProtocol.fromJson(Map<String, dynamic> json) {
    return MessageProtocol(
      from: MessageFrom.values[json['from']],
      to: MessageTo.values[json['to']],
      type: MessageTypes.values[json['type']],
      data: json['data'],
      isSuccess: json['is_success'],
      internalMain: json['internal_main'],
      internalIsolate: json['internal_isolate'],
      internalClient: json['internal_client'],
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
    bool? isSuccess,
    Map<String, dynamic>? internalMain,
    Map<String, dynamic>? internalIsolate,
    Map<String, dynamic>? internalClient,
  }) =>
      MessageProtocol(
        from: from,
        to: to,
        type: type,
        data: data ??= this.data,
        isSuccess: isSuccess ??= this.isSuccess,
        internalMain: internalMain ??= this.internalMain,
        internalIsolate: internalIsolate ??= this.internalIsolate,
        internalClient: internalClient ??= this.internalClient,
      );
}
