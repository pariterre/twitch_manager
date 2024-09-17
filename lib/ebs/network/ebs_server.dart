import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/twitch_ebs.dart';

part 'package:twitch_manager/ebs/network/handle_app_endpoints.dart';
part 'package:twitch_manager/ebs/network/handle_frontend_endpoints.dart';

final _logger = Logger('http_server');

///
/// Main entry point of the EBS server
void startEbsServer(
    {required NetworkParameters parameters,
    required TwitchEbsInfo ebsInfo,
    required TwitchEbsManagerAbstract Function(
            {required int broadcasterId,
            required TwitchEbsInfo ebsInfo,
            required SendPort sendPort})
        twitchEbsManagerFactory}) async {
  final httpServer = await _startServer(parameters);

  // Initialize the isolated manager so it can create new isolates
  IsolatedMainManager.initialize(twitchEbsManagerFactory);

  await for (final request in httpServer) {
    final ipAddress = request.connectionInfo?.remoteAddress.address;
    if (ipAddress == null) {
      _sendErrorResponse(
          request,
          HttpStatus.forbidden,
          MessageProtocol(
              from: MessageFrom.generic,
              to: MessageTo.generic,
              type: MessageTypes.response,
              isSuccess: false,
              data: {'error_message': 'Connexion refused'}));
      continue;
    }

    _logger.info(
        'New request received from $ipAddress (${parameters.rateLimiter.requestCount(ipAddress) + 1} / ${parameters.rateLimiter.maxRequests})');

    if (parameters.rateLimiter.isRateLimited(ipAddress)) {
      _sendErrorResponse(
          request,
          HttpStatus.tooManyRequests,
          MessageProtocol(
              from: MessageFrom.generic,
              to: MessageTo.generic,
              type: MessageTypes.response,
              isSuccess: false,
              data: {'error_message': 'Rate limited'}));
      continue;
    }

    if (request.method == 'OPTIONS') {
      _gardedHandleRequest(request, _handleOptionsRequest, ebsInfo: ebsInfo);
    } else if (request.method == 'GET') {
      _gardedHandleRequest(request, _handleGetHttpRequest, ebsInfo: ebsInfo);
    } else if (request.method == 'POST') {
      _gardedHandleRequest(request, _handlPostHttpRequest, ebsInfo: ebsInfo);
    } else {
      _sendErrorResponse(
          request,
          HttpStatus.methodNotAllowed,
          MessageProtocol(
              from: MessageFrom.generic,
              to: MessageTo.generic,
              type: MessageTypes.response,
              isSuccess: false,
              data: {
                'error_message': 'Invalid request method: ${request.method}'
              }));
    }
  }
}

Future<void> _gardedHandleRequest(HttpRequest request,
    Function(HttpRequest, {required TwitchEbsInfo ebsInfo}) handler,
    {required TwitchEbsInfo ebsInfo}) async {
  try {
    await handler(request, ebsInfo: ebsInfo);
  } on InvalidEndpointException {
    _sendErrorResponse(
        request,
        HttpStatus.notFound,
        MessageProtocol(
            from: MessageFrom.generic,
            to: MessageTo.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Invalid endpoint'}));
  } on UnauthorizedException {
    _sendErrorResponse(
        request,
        HttpStatus.unauthorized,
        MessageProtocol(
            from: MessageFrom.generic,
            to: MessageTo.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Unauthorized'}));
  } on ConnexionToWebSocketdRefusedException {
    _sendErrorResponse(
        request,
        HttpStatus.serviceUnavailable,
        MessageProtocol(
            from: MessageFrom.generic,
            to: MessageTo.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Connexion to WebSocketd refused'}));
  } catch (e) {
    _sendErrorResponse(
        request,
        HttpStatus.internalServerError,
        MessageProtocol(
            from: MessageFrom.generic,
            to: MessageTo.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'An error occurred: ${e.toString()}'}));
  }
}

///
/// Handle OPTIONS request for CORS preflight
Future<void> _handleOptionsRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..headers.add('Access-Control-Allow-Headers', 'Authorization, Content-Type')
    ..close();
}

Future<void> _handleGetHttpRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  if (request.uri.path.contains('/app/')) {
    _gardedHandleRequest(request, _handleAppHttpGetRequest, ebsInfo: ebsInfo);
  } else if (request.uri.path.contains('/frontend/')) {
    await _gardedHandleRequest(request, _handleFrontendHttpRequest,
        ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

Future<void> _handlPostHttpRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo}) async {
  if (request.uri.path.contains('/frontend/')) {
    await _handleFrontendHttpRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

_sendSuccessResponse(HttpRequest request, MessageProtocol message) {
  _logger.info('Sending success response: ${message.data}');
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..write(message.encode())
    ..close();
}

_sendErrorResponse(
    HttpRequest request, int statusCode, MessageProtocol message) {
  _logger.severe('Sending error response: ${message.data}');
  request.response
    ..statusCode = statusCode
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..write(message.encode())
    ..close();
}

Future<HttpServer> _startServer(NetworkParameters parameters) async {
  _logger.info(
      'Server starting on ${parameters.host}:${parameters.port}, ${parameters.usingSecure ? '' : 'not '}using SSL');

  return parameters.usingSecure
      ? await HttpServer.bindSecure(
          parameters.host,
          parameters.port,
          SecurityContext()
            ..useCertificateChain(parameters.certificatePath!)
            ..usePrivateKey(parameters.privateKeyPath!))
      : await HttpServer.bind(parameters.host, parameters.port);
}
