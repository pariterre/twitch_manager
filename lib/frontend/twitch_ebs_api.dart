import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:twitch_manager/abstract/twitch_authenticator.dart';
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';

final _logger = Logger('TwitchEbsApi');

///
/// This is the frontend implementation of the Twitch EBS API. The EBS side
/// must be implemented in a separate project, and there is unfortunately no
/// way to provide a complete example of the EBS side in this project, as it
/// can be implemented in any language or framework.
class TwitchEbsApi {
  final TwitchFrontendInfo appInfo;
  final TwitchJwtAuthenticator authenticator;

  TwitchEbsApi({required this.appInfo, required this.authenticator});

  ///
  /// This method sends a POST request to the EBS server. The [endpoint] is the
  /// path to the endpoint on the EBS server. The method expect the endpoint
  /// to include the leading slash (if required). The method returns a Map<String, dynamic>
  /// with the response from the EBS server. If the endpoint is not found,
  /// the method will throw an exception.
  Future<Map<String, dynamic>> postRequest(Map<String, dynamic>? body) async {
    try {
      return await _sendPostRequestToEbs(appInfo.ebsUri, authenticator, body);
    } catch (e) {
      _logger.info('Error making request: $e');
      return {'status': 'NOK', 'error_message': e.toString()};
    }
  }
}

Future<Map<String, dynamic>> _sendPostRequestToEbs(Uri endpoint,
    TwitchJwtAuthenticator authenticator, Map<String, dynamic>? body) async {
  // Making a simple POST request with the bearer token
  try {
    final response = await http.post(endpoint,
        headers: {
          'Authorization': 'Bearer ${authenticator.ebsToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Request failed with status: ${response.statusCode} with message: ${response.body}');
    }
  } catch (e) {
    throw Exception('Error making request: $e');
  }
}
