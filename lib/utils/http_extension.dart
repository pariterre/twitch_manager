import 'package:http/http.dart' as http;

Future<http.Response> timedHttpGet(Uri uri,
    {Map<String, String>? headers, duration = const Duration(seconds: 10)}) {
  return http.get(uri, headers: headers).timeout(duration, onTimeout: () {
    return http.Response('{"status": 408, "message": "Request Timeout"}', 408);
  });
}

Future<http.Response> timedHttpPost(Uri uri,
    {Map<String, String>? headers, Object? body}) {
  return http
      .post(uri, headers: headers, body: body)
      .timeout(const Duration(seconds: 10), onTimeout: () {
    return http.Response('{"status": 408, "message": "Request Timeout"}', 408);
  });
}

Future<http.Response> timedHttpPatch(Uri uri,
    {Map<String, String>? headers, Object? body}) {
  return http
      .patch(uri, headers: headers, body: body)
      .timeout(const Duration(seconds: 10), onTimeout: () {
    return http.Response('{"status": 408, "message": "Request Timeout"}', 408);
  });
}

Future<http.Response> timedHttpDelete(Uri uri,
    {Map<String, String>? headers, Object? body}) {
  return http
      .delete(uri, headers: headers, body: body)
      .timeout(const Duration(seconds: 10), onTimeout: () {
    return http.Response('{"status": 408, "message": "Request Timeout"}', 408);
  });
}
