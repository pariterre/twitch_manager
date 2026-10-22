import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:twitch_manager/frontend/twitch_frontend_info.dart';

class TwitchFrontendHelpers {
  ///
  /// Get a self-signed JWT from the EBS server. This allows to connect to the
  /// EBS, but will not be able to use the Twitch related resources, such as
  /// accessing the channel or user information.
  static Future<String> getSelfSignedJwt(
      {required TwitchFrontendInfo appInfo,
      required Map<String, dynamic> data}) async {
    // final uri = Uri.parse('${appInfo.ebsUri}/frontend/sign-connect-info');
    final uri = Uri.parse('http://localhost:3011/frontend/sign-connect-info');
    final response = await http.post(uri,
        body: jsonEncode(data), headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['jwt'] as String;
    } else {
      throw Exception('Failed to get self-signed JWT');
    }
  }
}
