import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/models/twitch_authenticators.dart';
import 'package:twitch_manager/twitch_manager.dart';

///
/// This is the frontend implementation of the Twitch EBS API. The EBS side
/// must be implemented in a separate project, and there is unfortunately no
/// way to provide a complete example of the EBS side in this project, as it
/// can be implemented in any language or framework.
class TwitchApiToEbs {
  final TwitchFrontendInfo appInfo;
  final TwitchJwtAuthenticator authenticator;

  TwitchApiToEbs({required this.appInfo, required this.authenticator});

  Future<Map<String, dynamic>> get(String endpoint) async {
    return _sendGetRequestToEbs(
        Uri.parse('${appInfo.ebsUri}/$endpoint'), authenticator);
  }

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    return _sendPostRequestToEbs(
        Uri.parse('${appInfo.ebsUri}/$endpoint'), authenticator, body);
  }
}

Future<Map<String, dynamic>> _sendGetRequestToEbs(
    Uri endpoint, TwitchJwtAuthenticator authenticator) async {
  // Making a simple GET request with the bearer token
  try {
    final response = await http.get(endpoint, headers: {
      'Authorization': 'Bearer ${authenticator.ebsToken}',
      'Content-Type': 'application/json',
    });

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error making request: $e');
  }
}

Future<Map<String, dynamic>> _sendPostRequestToEbs(Uri endpoint,
    TwitchJwtAuthenticator authenticator, Map<String, dynamic> body) async {
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
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error making request: $e');
  }
}
