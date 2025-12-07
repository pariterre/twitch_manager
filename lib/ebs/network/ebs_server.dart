import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/common/communication_protocols.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials.dart';
import 'package:twitch_manager/ebs/credentials/twitch_ebs_credentials_storage.dart';
import 'package:twitch_manager/ebs/ebs_exceptions.dart';
import 'package:twitch_manager/ebs/main_isolated_manager.dart';
import 'package:twitch_manager/ebs/network/network_parameters.dart';
import 'package:twitch_manager/ebs/twitch_ebs_info.dart';
import 'package:twitch_manager/ebs/twitch_ebs_manager_abstract.dart';
import 'package:twitch_manager/utils/http_extension.dart';

part 'package:twitch_manager/ebs/network/handle_app_endpoints.dart';
part 'package:twitch_manager/ebs/network/handle_frontend_endpoints.dart';

final _logger = Logger('EbsServer');

///
/// Main entry point of the EBS server
void startEbsServer({
  required NetworkParameters parameters,
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
  required TwitchEbsManagerAbstract Function({
    required String broadcasterId,
    required TwitchEbsInfo ebsInfo,
    required SendPort sendPort,
  }) twitchEbsManagerFactory,
}) async {
  final httpServer = await _startServer(parameters);

  // Initialize the isolated manager so it can create new isolates
  MainIsolatedManager.initialize(twitchEbsManagerFactory);

  await for (final request in httpServer) {
    final ipAddress = request.connectionInfo?.remoteAddress.address;
    if (ipAddress == null) {
      _sendErrorResponse(
          request,
          HttpStatus.forbidden,
          MessageProtocol(
              to: MessageTo.generic,
              from: MessageFrom.generic,
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
              to: MessageTo.generic,
              from: MessageFrom.generic,
              type: MessageTypes.response,
              isSuccess: false,
              data: {'error_message': 'Rate limited'}));
      continue;
    }

    if (request.method == 'OPTIONS') {
      _guardedHandleRequest(request, _handleOptionsRequest,
          ebsInfo: ebsInfo, credentialsStorage: credentialsStorage);
    } else if (request.method == 'GET') {
      _guardedHandleRequest(request, _handleGetHttpRequest,
          ebsInfo: ebsInfo, credentialsStorage: credentialsStorage);
    } else {
      _sendErrorResponse(
          request,
          HttpStatus.methodNotAllowed,
          MessageProtocol(
              to: MessageTo.generic,
              from: MessageFrom.generic,
              type: MessageTypes.response,
              isSuccess: false,
              data: {
                'error_message': 'Invalid request method: ${request.method}'
              }));
    }
  }
}

Future<void> _guardedHandleRequest(
    HttpRequest request,
    Function(HttpRequest,
            {required TwitchEbsInfo ebsInfo,
            required TwitchEbsCredentialsStorage credentialsStorage})
        handler,
    {required TwitchEbsInfo ebsInfo,
    required TwitchEbsCredentialsStorage credentialsStorage}) async {
  try {
    await handler(request,
        ebsInfo: ebsInfo, credentialsStorage: credentialsStorage);
  } on InvalidEndpointException {
    _sendErrorResponse(
        request,
        HttpStatus.notFound,
        MessageProtocol(
            to: MessageTo.generic,
            from: MessageFrom.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Invalid endpoint'}));
  } on UnauthorizedException {
    _sendErrorResponse(
        request,
        HttpStatus.unauthorized,
        MessageProtocol(
            to: MessageTo.generic,
            from: MessageFrom.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Unauthorized'}));
  } on ConnexionToWebSocketdRefusedException {
    _sendErrorResponse(
        request,
        HttpStatus.serviceUnavailable,
        MessageProtocol(
            to: MessageTo.generic,
            from: MessageFrom.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'Connexion to WebSocket refused'}));
  } catch (e) {
    _sendErrorResponse(
        request,
        HttpStatus.internalServerError,
        MessageProtocol(
            to: MessageTo.generic,
            from: MessageFrom.generic,
            type: MessageTypes.response,
            isSuccess: false,
            data: {'error_message': 'An error occurred: ${e.toString()}'}));
  }
}

///
/// Handle OPTIONS request for CORS preflight
Future<void> _handleOptionsRequest(HttpRequest request,
    {required TwitchEbsInfo ebsInfo,
    required TwitchEbsCredentialsStorage credentialsStorage}) async {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS')
    ..headers.add('Access-Control-Allow-Headers', 'Authorization, Content-Type')
    ..close();
}

Future<void> _handleGetHttpRequest(
  HttpRequest request, {
  required TwitchEbsInfo ebsInfo,
  required TwitchEbsCredentialsStorage credentialsStorage,
}) async {
  if (request.uri.path.contains('/app')) {
    await _handleAppGetRequest(request,
        ebsInfo: ebsInfo, credentialsStorage: credentialsStorage);
  } else if (request.uri.path.contains('/frontend')) {
    await _handleFrontendGetRequest(request, ebsInfo: ebsInfo);
  } else {
    throw InvalidEndpointException();
  }
}

void _sendErrorResponse(
    HttpRequest request, int statusCode, MessageProtocol message) {
  _logger.severe('Sending error response: ${message.data}');
  try {
    request.response
      ..statusCode = statusCode
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..write(message.encode());
  } catch (e) {
    _logger.severe('Error while sending error response: $e');
  }
  request.response.close();
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
