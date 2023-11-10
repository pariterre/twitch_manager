import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:http/http.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/models/twitch_authenticator.dart';
import 'package:twitch_manager/models/twitch_listener.dart';
import 'package:twitch_manager/twitch_app_info.dart';
import 'package:twitch_manager/twitch_scope.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;

const _twitchEventUri = 'wss://eventsub.wss.twitch.tv/ws';
const _twitchHelixUri = 'https://api.twitch.tv/helix/eventsub/subscriptions';

class TwitchEventResponse {
  final String requestingId;
  final String requestingUser;
  final String rewardRedemption;
  final int cost;
  final String message;

  TwitchEventResponse({
    required this.requestingId,
    required this.requestingUser,
    required this.rewardRedemption,
    required this.cost,
    required this.message,
  });

  factory TwitchEventResponse.fromMap(Map<String, dynamic> map) {
    return TwitchEventResponse(
      requestingId: map['payload']['event']['user_id'],
      requestingUser: map['payload']['event']['user_name'],
      rewardRedemption: map['payload']['event']['reward']['title'],
      cost: map['payload']['event']['reward']['cost'],
      message: map['payload']['event']['user_input'],
    );
  }

  @override
  String toString() {
    String message =
        '$requestingUser ($requestingId) has made a reward redemption for $cost: $rewardRedemption';
    if (message.isNotEmpty) {
      message += ' with the added following message: $message';
    }

    return message;
  }
}

extension ScopeSubscription on TwitchScope {
  Map cratfSubscriptionRequest({
    required String streamerId,
    required String sessionId,
  }) {
    switch (this) {
      case TwitchScope.rewardRedemption:
        return {
          'type': 'channel.channel_points_custom_reward_redemption.add',
          'version': '1',
          'condition': {
            'broadcaster_user_id': streamerId,
            'moderator_user_id': streamerId,
          },
          'transport': {'method': 'websocket', 'session_id': sessionId},
        };
      default:
        throw 'The scope $this is not supported for event subscription';
    }
  }
}

class TwitchEvent {
  ///
  /// The constructor for the Twitch Event
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchEvent> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
    required TwitchApi api,
  }) async {
    final twitchEvent = TwitchEvent._(appInfo, authenticator, api);

    // Communication procedure
    twitchEvent._channel = ws.WebSocket(Uri.parse(_twitchEventUri));
    twitchEvent._channel!.messages
        .listen((message) => twitchEvent._responseFromSubscription(message));

    // Wait until response is received
    while (twitchEvent._sessionId == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Send the subscription request
    for (final eventScope
        in appInfo.scope.where((e) => e.scopeType == ScopeType.event)) {
      twitchEvent._sendPostSubscribtionRequest(eventScope);
    }

    // Return the fully functionnal TwitchEvent
    return twitchEvent;
  }

  Future<void> disconnect() async {
    for (int i = 0; i < _subscriptionIds.length; i++) {
      _sendDeleteSubscribtionRequest(i);
    }
    _subscriptionIds.clear();

    _eventListeners.disposeAll();
    _channel?.close();
  }

  ////// INTERNAL //////
  final _eventListeners =
      TwitchGenericListener<void Function(TwitchEventResponse event)>();
  ws.WebSocket? _channel;

  ///
  /// ATTRIBUTES
  final TwitchApi _api;
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator _authenticator;
  String? _sessionId;
  final List<String?> _subscriptionIds = [];

  ///
  /// Private constructor
  TwitchEvent._(
    this._appInfo,
    this._authenticator,
    this._api,
  );

  ///
  /// Manage a response from a subscription
  void _responseFromSubscription(message) {
    final map = jsonDecode(message);

    // If this is the first call, we need to get the session id then return
    if (_sessionId == null) {
      // This is the shakehand
      dev.log('Connected to the Twitch Event API');
      _sessionId = map['payload']['session']['id'];
      return;
    }

    // If the payload is empty, this is a keep alive response, so do nothing
    if ((map['payload'] as Map).isEmpty) return;

    // If we get here, this is an actual response from Twitch. Let's parse it
    // log and notify the listeners
    final response = TwitchEventResponse.fromMap(map);
    dev.log(response.toString());
    _eventListeners.listeners.forEach((key, callback) => callback(response));
  }

  ///
  /// Send the actual Post request to Twitch
  Future<void> _sendPostSubscribtionRequest(TwitchScope scope) async {
    if (scope.scopeType != ScopeType.event) {
      throw 'The scope must be of type event';
    }

    // This method cannot be called if the session id is not set
    if (_sessionId == null) return;

    // Crafting the actual post request to subscribe and wait for the answer
    final response = await post(
      Uri.parse(_twitchHelixUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader:
            'Bearer ${_authenticator.streamerOauthKey}',
        'Client-Id': _appInfo.twitchAppId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(scope.cratfSubscriptionRequest(
          sessionId: _sessionId!, streamerId: _api.streamerId.toString())),
    );

    // Parse the answer to see if the subscription was successful
    final responseDecoded = await jsonDecode(response.body) as Map;
    if (responseDecoded.containsKey('data') &&
        responseDecoded['data'][0]['status'] == 'enabled') {
      // Success
      _subscriptionIds.add(responseDecoded['data'][0]['id']);
      return;
    } else {
      // Failed
      dev.log(responseDecoded.toString());
      return;
    }
  }

  ///
  /// Send the actual Post request to Twitch
  Future<void> _sendDeleteSubscribtionRequest(int index) async {
    // This method cannot be called if the session id is not set
    if (_sessionId == null) return;

    // Crafting the actual post request to subscribe and wait for the answer
    await delete(
      Uri.parse(_twitchHelixUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader:
            'Bearer ${_authenticator.streamerOauthKey}',
        'Client-Id': _appInfo.twitchAppId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id': _subscriptionIds[index]}),
    );
  }
}

class TwitchEventMock extends TwitchEvent {
  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchEventMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticatorMock authenticator,
    required TwitchApiMock api,
  }) async {
    return TwitchEventMock._(appInfo, authenticator, api);
  }

  ////// INTERNAL //////

  ///
  /// Private constructor
  TwitchEventMock._(TwitchAppInfo appInfo,
      TwitchAuthenticatorMock authenticator, TwitchApiMock api)
      : super._(appInfo, authenticator, api);
}
