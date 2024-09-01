import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _clients = <String, String>{};
final _logger = Logger('authentication_server');

///
/// Manage the communication between the client and twitch. An example of the
/// expected communication is implemented in [resources/twitch_redirect_example.html]
/// and in the example of the [twitch_manager] package.
///
/// The arguments are:
/// - --host=<host>: the host to bind the server to. Default is 'localhost'.
/// - --port=<port>: the port to bind the server to. Default is 3000.
/// - --ssl=<cert.pem>,<key.pem>: the certificate and key to use for SSL. If
///  empty, SSL (http) is not used (default).
void main(List<String> arguments) async {
  if (arguments.contains('--help')) {
    print('''
    Manage the communication between the client and twitch. An example of the
    expected communication is implemented in [resources/twitch_redirect_example.html]
    and in the example of the [twitch_manager] package.

    The arguments are:
    - --host=<host>: the host to bind the server to. Default is 'localhost'.
    - --port=<port>: the port to bind the server to. Default is 3000.
    - --ssl=<cert.pem>,<key.pem>: the certificate and key to use for SSL. If
      empty, SSL (http) is not used (default).
    - --log=<log_file>: the log file to write the logs to. Default is
      'authentication_server.log'.
    ''');
    return;
  }

  // log to a log file
  final logFilename = arguments
      .firstWhere((e) => e.startsWith('--log=') || e.startsWith('-l='),
          orElse: () => '--log=authentication_server.log')
      .split('=')[1];
  final logFile = File(logFilename);
  logFile.writeAsStringSync(
      '-----------------------------------\n'
      'Starting new log at ${DateTime.now()}\n',
      mode: FileMode.append);
  Logger.root.onRecord.listen((record) {
    final message = '${record.time}: ${record.message}';
    logFile.writeAsStringSync('$message\n', mode: FileMode.append);
    print(message);
  });

  final host = arguments
      .firstWhere((e) => e.startsWith('--host=') || e.startsWith('-h='),
          orElse: () => '--host=localhost')
      .split('=')[1];

  final port = int.parse(arguments
      .firstWhere((e) => e.startsWith('--port=') || e.startsWith('-p='),
          orElse: () => '--port=3000')
      .split('=')[1]);

  final ssl = arguments
      .firstWhere((e) => e.startsWith('--ssl=') || e.startsWith('-s='),
          orElse: () => '--ssl=')
      .split('=')[1];
  final sslCert = ssl.isEmpty ? '' : ssl.split(',')[0];
  final sslKey = ssl.isEmpty ? '' : ssl.split(',')[1];
  if (ssl.isNotEmpty && (sslCert.isEmpty || sslKey.isEmpty)) {
    _logger.severe('Invalid SSL certificate and key, the expected format is: '
        '--ssl=<cert.pem>,<key.pem>');
    return;
  }

  _logger.info('Server starting on $host:$port, SSL: ${ssl.isNotEmpty}');
  HttpServer server = sslKey.isEmpty
      ? await HttpServer.bind(host, port)
      : await HttpServer.bindSecure(
          host,
          port,
          SecurityContext()
            ..useCertificateChain(sslCert)
            ..usePrivateKey(sslKey));

  await for (HttpRequest request in server) {
    _logger.info('New ${request.method} request at ${request.uri.path}');
    if (request.method == 'OPTIONS') {
      _handleOptionsRequest(request);
    } else if (request.method == 'GET' && request.uri.path == '/token') {
      _handleGetTokenRequest(request);
    } else if (request.method == 'POST' && request.uri.path == '/token') {
      _handlePostTokenRequest(request);
    } else {
      _sendErrorResponse(
          request, HttpStatus.methodNotAllowed, 'Method not allowed');
    }
  }
}

///
/// Handle OPTIONS request for CORS preflight
void _handleOptionsRequest(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..headers.add('Access-Control-Allow-Headers', 'Content-Type')
    ..close();
}

///
/// Handle client request
void _handleGetTokenRequest(HttpRequest request) async {
  // Get the state token from the query parameters
  final stateToken = request.uri.queryParameters['state'];
  if (stateToken == null) {
    _sendErrorResponse(request, HttpStatus.badRequest, 'State token not found');
    return;
  }

  // Validate the state token
  // The state is a string of 25 digits. The 4th character is 6 and the 12th
  // character is 2. The sum of all the digits is calculated and the last digit
  // is adjusted to make the sum 9.
  if (stateToken.length != 25 ||
      stateToken[3] != '6' ||
      stateToken[11] != '2' ||
      stateToken.codeUnits.reduce((a, b) => a + b) % 10 != 9) {
    _sendErrorResponse(request, HttpStatus.badRequest, 'Invalid state token');
    return;
  }

  // Get the token from the stored data, try for a maximum of 1 minute
  final downtimeThreshold = DateTime.now().add(Duration(minutes: 1));
  String? token;
  while (DateTime.now().isBefore(downtimeThreshold)) {
    if (_clients.containsKey(stateToken)) {
      // Pop the token from the stored data
      token = _clients.remove(stateToken);
      break;
    }
    await Future.delayed(Duration(milliseconds: 100));
  }
  if (token == null) {
    _sendErrorResponse(request, HttpStatus.badRequest, 'Token not found');
    return;
  }

  // Send the token back to the client
  _sendSuccessResponse(request, {'access_token': token, 'state': stateToken});
}

///
/// Handle token request
void _handlePostTokenRequest(HttpRequest request) async {
  // Read the request body
  try {
    // Read the request body
    String content = await utf8.decoder.bind(request).join();
    // Parse the JSON data
    var data = jsonDecode(content)["fragment"];

    // Extract the state from the fragment (&state=...&)
    final stateMatch = RegExp(r'^.*&state=([0-9]*)&.*$').firstMatch(data);
    if (stateMatch == null || stateMatch.groupCount < 1) {
      _logger.severe('State not found, droping client');
      return;
    }
    String stateToken = stateMatch.group(1)!;

    // Extract the token from the fragment (&access_token=...&)
    final tokenMatch = RegExp(r'^.*access_token=([^&]*)&.*$').firstMatch(data);
    if (tokenMatch == null || tokenMatch.groupCount < 1) {
      _logger.severe('Token not found, droping client');
      return;
    }
    final token = tokenMatch.group(1)!;

    // Store the token so it can be sent to the client
    _logger.info('Twitch OAUTH token received for $stateToken');
    _clients[stateToken] = token;

    // Remove token in 5 minutes if not requested
    Future.delayed(Duration(minutes: 5), () {
      _clients.remove(stateToken);
    });

    // Send a response back to the client
    _sendSuccessResponse(request, {'state': 'OK'});
  } catch (e) {
    _sendErrorResponse(
        request, HttpStatus.internalServerError, 'Error processing request');
  }
}

_sendSuccessResponse(HttpRequest request, Map<String, dynamic> data) {
  _logger.info('Sending success response: $data');
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..write(json.encode(data))
    ..close();
}

_sendErrorResponse(HttpRequest request, int statusCode, String message) {
  _logger.severe('Sending error response: $message');
  request.response
    ..statusCode = statusCode
    ..headers.add('Access-Control-Allow-Origin', '*')
    ..write(message)
    ..close();
}
