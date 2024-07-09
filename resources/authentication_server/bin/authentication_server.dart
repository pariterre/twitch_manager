import 'dart:convert';
import 'dart:io';

final _clients = <String, String>{};

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
  final hostArg = arguments.firstWhere(
      (e) => e.startsWith('--host=') || e.startsWith('-h='),
      orElse: () => '--host=localhost');
  final host = hostArg.split('=')[1];

  final portArg = arguments.firstWhere(
      (e) => e.startsWith('--port=') || e.startsWith('-p='),
      orElse: () => '--port=3000');
  final port = int.parse(portArg.split('=')[1]);

  final sslArg = arguments.firstWhere(
      (e) => e.startsWith('--ssl=') || e.startsWith('-s='),
      orElse: () => '--ssl=');
  final ssl = sslArg.split('=')[1];
  final sslCert = ssl.isEmpty ? '' : ssl.split(',')[0];
  final sslKey = ssl.isEmpty ? '' : ssl.split(',')[1];
  if (ssl.isNotEmpty && (sslCert.isEmpty || sslKey.isEmpty)) {
    print('Invalid SSL certificate and key, the expected format is: '
        '--ssl=<cert.pem>,<key.pem>');
    return;
  }

  print('Server starting on $host:$port');
  HttpServer server = sslKey.isEmpty
      ? await HttpServer.bind(host, port)
      : await HttpServer.bindSecure(
          host,
          port,
          SecurityContext()
            ..useCertificateChain(sslCert)
            ..usePrivateKey(sslKey));

  await for (HttpRequest request in server) {
    print('New ${request.method} request: ${request.uri.path}');
    if (request.method == 'OPTIONS') {
      _handleOptionsRequest(request);
    } else if (request.method == 'GET' && request.uri.path == '/gettoken') {
      _handleGetTokenRequest(request);
    } else if (request.method == 'POST' && request.uri.path == '/posttoken') {
      _handlePostTokenRequest(request);
    } else {
      _handleConnexionRefused(request);
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
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('State token not found')
      ..close();
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
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('Invalid state token')
      ..close();
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
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Token not found')
      ..close();
    return;
  }

  // Send the token back to the client
  request.response
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode({'access_token': token, 'state': stateToken}))
    ..close();
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
      print('State not found, droping client');
      return;
    }
    String stateToken = stateMatch.group(1)!;

    // Extract the token from the fragment (&access_token=...&)
    final tokenMatch = RegExp(r'^.*access_token=([^&]*)&.*$').firstMatch(data);
    if (tokenMatch == null || tokenMatch.groupCount < 1) {
      print('Token not found, droping client');
      return;
    }
    final token = tokenMatch.group(1)!;

    // Store the token so it can be sent to the client
    _clients[stateToken] = token;

    // Remove token in 5 minutes if not requested
    Future.delayed(Duration(minutes: 5), () {
      _clients.remove(stateToken);
    });

    // Send a response back to the client
    request.response
      ..statusCode = HttpStatus.ok
      ..write('Data received successfully')
      ..close();
  } catch (e) {
    print('Error processing request: $e');
    // Handle any errors
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Error processing request: $e')
      ..close();
  }
}

/// Handle connexion refused
void _handleConnexionRefused(HttpRequest request) {
  request.response
    ..statusCode = HttpStatus.forbidden
    ..write('Connexion refused')
    ..close();
}
