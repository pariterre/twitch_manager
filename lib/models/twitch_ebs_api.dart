import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/models/twitch_authenticators.dart';
import 'package:twitch_manager/twitch_manager.dart';

///
/// This is the frontend implementation of the Twitch EBS API. The EBS side
/// must be implemented in a separate project, and there is unfortunately no
/// way to provide a complete example of the EBS side in this project, as it
/// can be implemented in any language or framework.
class TwitchEbsApi {
  final TwitchFrontendInfo appInfo;
  final TwitchJwtAuthenticator authenticator;

  TwitchEbsApi({required this.appInfo, required this.authenticator});

  Future<Map<String, dynamic>> coucou() async {
    return _sendGetRequestToEbs(
        Uri.parse('${appInfo.ebsUri}/coucou'), authenticator);
  }

  ///
  /// Register the frontend to the EBS. This is a simple GET request to the
  /// EBS with the bearer token in the header. The EBS can then use this token
  /// to verify, both validating the user and the frontend communicating with
  /// Twitch.
  ///
  /// It assumes that the EBS has an endpoint at /initialize.
  static void registerToEbs(
      TwitchFrontendInfo appInfo, TwitchJwtAuthenticator authenticator) async {
    _sendGetRequestToEbs(
        Uri.parse('${appInfo.ebsUri}/initialize'), authenticator);
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
