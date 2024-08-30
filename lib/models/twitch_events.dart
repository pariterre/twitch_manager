import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:twitch_manager/models/twitch_api.dart';
import 'package:twitch_manager/models/twitch_authenticators.dart';
import 'package:twitch_manager/models/twitch_listener.dart';
import 'package:twitch_manager/twitch_manager.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;

const _twitchEventsUri = 'wss://eventsub.wss.twitch.tv/ws';
const _twitchHelixUri = 'https://api.twitch.tv/helix/eventsub/subscriptions';

final _logger = Logger('TwitchEvents');

class TwitchEvent {
  final String eventId;
  final String requestingUserId;
  final String requestingUser;
  final String message;

  TwitchEvent({
    required this.eventId,
    required this.requestingUserId,
    required this.requestingUser,
    required this.message,
  });

  factory TwitchEvent.fromMap(Map<String, dynamic> map) {
    return TwitchEvent(
      eventId: map['payload']['event']['id'],
      requestingUserId: map['payload']['event']['user_id'],
      requestingUser: map['payload']['event']['user_name'],
      message: map['payload']['event']['user_input'],
    );
  }

  @override
  String toString() {
    String message = 'Event from $requestingUser ($requestingUserId)';
    if (message.isNotEmpty) {
      message += ' with the added following message: $message';
    }

    return message;
  }

  TwitchEvent copyWith({
    String? eventId,
    String? requestingUserId,
    String? requestingUser,
    String? message,
  }) {
    return TwitchEvent(
      eventId: eventId ?? this.eventId,
      requestingUserId: requestingUserId ?? this.requestingUserId,
      requestingUser: requestingUser ?? this.requestingUser,
      message: message ?? this.message,
    );
  }
}

enum TwitchRewardRedemptionStatus {
  fulfilled,
  canceled;

  @override
  String toString() {
    switch (this) {
      case TwitchRewardRedemptionStatus.fulfilled:
        return 'FULFILLED';
      case TwitchRewardRedemptionStatus.canceled:
        return 'CANCELED';
    }
  }
}

class TwitchRewardRedemption extends TwitchEvent {
  TwitchRewardRedemption({
    required this.rewardRedemptionId,
    required this.rewardRedemption,
    required this.cost,
    required super.eventId,
    required super.requestingUserId,
    required super.requestingUser,
    required super.message,
  });

  TwitchRewardRedemption.minimal({
    required this.rewardRedemption,
    required this.cost,
  })  : rewardRedemptionId = '',
        super(
            eventId: '', requestingUserId: '', requestingUser: '', message: '');

  final int cost;
  final String rewardRedemptionId;
  final String rewardRedemption;

  factory TwitchRewardRedemption.fromMap(Map<String, dynamic> map) {
    final event = TwitchEvent.fromMap(map);
    return TwitchRewardRedemption(
      eventId: event.eventId,
      requestingUserId: event.requestingUserId,
      requestingUser: event.requestingUser,
      cost: map['payload']['event']['reward']['cost'],
      message: event.message,
      rewardRedemptionId: map['payload']['event']['reward']['id'],
      rewardRedemption: map['payload']['event']['reward']['title'],
    );
  }

  @override
  String toString() {
    String message =
        '$requestingUser ($requestingUserId) has made a reward redemption for $cost: $rewardRedemption';
    if (message.isNotEmpty) {
      message += ' with the added following message: $message';
    }

    return message;
  }

  @override
  TwitchRewardRedemption copyWith({
    String? eventId,
    String? requestingUserId,
    String? requestingUser,
    int? cost,
    String? message,
    String? rewardRedemptionId,
    String? rewardRedemption,
  }) {
    return TwitchRewardRedemption(
      eventId: eventId ?? this.eventId,
      requestingUserId: requestingUserId ?? this.requestingUserId,
      requestingUser: requestingUser ?? this.requestingUser,
      cost: cost ?? this.cost,
      message: message ?? this.message,
      rewardRedemptionId: rewardRedemptionId ?? this.rewardRedemptionId,
      rewardRedemption: rewardRedemption ?? this.rewardRedemption,
    );
  }
}

extension ScopeSubscription on TwitchScope {
  Map cratfSubscriptionRequest({
    required String streamerId,
    required String sessionId,
  }) {
    switch (this) {
      case TwitchScope.readRewardRedemption:
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

class TwitchEvents {
  ///
  /// The constructor for the TwitchEvents
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchEvents> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
    required TwitchClientApi api,
  }) async {
    _logger.config('Connecting to Twitch events API...');

    final twitchEvents = TwitchEvents._(appInfo, authenticator, api);

    // Communication procedure
    twitchEvents._channel = ws.WebSocket(Uri.parse(_twitchEventsUri));
    twitchEvents._channel!.messages
        .listen((message) => twitchEvents._responseFromSubscription(message));

    // Wait until response is received
    while (twitchEvents._sessionId == null) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Send the subscription request
    for (final eventScope
        in appInfo.scope.where((e) => e.scopeType == ScopeType.events)) {
      twitchEvents._sendPostSubscribtionRequest(eventScope);
    }

    // Return the fully functionnal TwitchEvents
    _logger.config('Connected to Twitch events API');
    return twitchEvents;
  }

  ////// PUBLIC //////
  bool get isConnected => _isConnected;

  ///
  /// Subscribe to a specific reward redemption event. When a reward is redeemed
  /// the [onRewardRedeemed] callback will be called. If the reward is should
  /// answered by the user, then they should call the [updateRewardRedemption]
  /// of the api structure.
  final onRewardRedeemed =
      TwitchGenericListener<void Function(TwitchRewardRedemption reward)>();

  ///
  /// Unsubscribe to all events and close connexion
  Future<void> disconnect() async {
    _logger.info('Disconnecting from Twitch events API...');

    for (int i = 0; i < _subscriptionIds.length; i++) {
      _sendDeleteSubscribtionRequest(i);
    }
    _subscriptionIds.clear();

    onRewardRedeemed.clearListeners();
    _channel?.close();

    _isConnected = false;
    _logger.info('Disconnected from Twitch events API');
  }

  ////// INTERNAL //////
  ws.WebSocket? _channel;

  ///
  /// ATTRIBUTES
  bool _isConnected = false;
  final TwitchClientApi _api;
  final TwitchAppInfo _appInfo;
  final TwitchAuthenticator _authenticator;
  String? _sessionId;
  final List<String?> _subscriptionIds = [];

  ///
  /// Private constructor
  TwitchEvents._(
    this._appInfo,
    this._authenticator,
    this._api,
  );

  ///
  /// Manage a response from a subscription
  void _responseFromSubscription(message) {
    _logger.fine('Received message from Twitch events: $message');

    final map = jsonDecode(message);

    // If this is the first call, we need to get the session id then return
    if (_sessionId == null) {
      // This is the shakehand
      _logger.fine('Connected to the TwitchEvents API');
      _sessionId = map['payload']['session']['id'];
      return;
    }

    // If the payload is empty, this is a keep alive response, so do nothing
    final payload = map['payload'] as Map;
    if (payload.isEmpty || !payload.containsKey('event')) {
      _logger.fine('Keep alive message from Twitch events');
      return;
    }

    // If we get here, this is an actual response from Twitch. Let's parse it
    // log and notify the listeners
    if ((payload['event'] as Map).containsKey('reward')) {
      _logger.info('Reward redemption received from Twitch events');
      final response = TwitchRewardRedemption.fromMap(map);
      onRewardRedeemed.notifyListeners((callback) => callback(response));
    } else {
      final response = TwitchEvent.fromMap(map);
      _logger.info('Event received from Twitch events ($response)');
    }
  }

  ///
  /// Send the actual Post request to Twitch
  Future<void> _sendPostSubscribtionRequest(TwitchScope scope) async {
    _logger.info('Subscribing to Twitch events...');

    if (scope.scopeType != ScopeType.events) {
      _logger.severe('The scope must be of type events');
      throw 'The scope must be of type events';
    }

    // This method cannot be called if the session id is not set
    if (_sessionId == null) {
      _logger.severe('Cannot subscribe to an event without a session id');
      return;
    }

    // Crafting the actual post request to subscribe and wait for the answer
    final response = await post(
      Uri.parse(_twitchHelixUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${_authenticator.bearerKey}',
        'Client-Id': _appInfo.twitchClientId,
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
      _isConnected = true;
      _logger.info('Twitch events subscribed');
      return;
    } else {
      // Failed
      _isConnected = false;
      _logger.severe(
          'Failed to subscribe to Twitch events: ${responseDecoded['message']}');
      return;
    }
  }

  ///
  /// Send the actual Delete request to Twitch
  Future<void> _sendDeleteSubscribtionRequest(int index) async {
    _logger.info('Unsubscribing to Twitch events...');

    // This method cannot be called if the session id is not set
    if (_sessionId == null) {
      _logger.severe('Cannot unsubscribe to an event without a session id');
      return;
    }

    // Crafting the actual delete request and wait for the answer
    await delete(
      Uri.parse(_twitchHelixUri),
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${_authenticator.bearerKey}',
        'Client-Id': _appInfo.twitchClientId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id': _subscriptionIds[index]}),
    );

    _subscriptionIds.removeAt(index);
    _logger.info('Twitch events unsubscribed');
  }
}

class TwitchEventsMock extends TwitchEvents {
  ///
  /// The constructor for the Twitch API
  /// [appInfo] holds all the information required to run the API
  /// [authenticator] holds the OAuth key to communicate with the API
  static Future<TwitchEventsMock> factory({
    required TwitchAppInfo appInfo,
    required TwitchAuthenticator authenticator,
    required TwitchApiMock api,
    required TwitchDebugPanelOptions debugPanelOptions,
  }) async {
    return TwitchEventsMock._(appInfo, authenticator, api, debugPanelOptions);
  }

  ////// PUBLIC //////

  // Simulate a reward redemption
  void simulateRewardRedemption(event) => onRewardRedeemed
      .notifyListeners((callback) => callback(event as TwitchRewardRedemption));

  ////// INTERNAL //////

  ///
  /// Private constructor
  TwitchEventsMock._(
    super.appInfo,
    super.authenticator,
    TwitchApiMock super.api,
    TwitchDebugPanelOptions debugPanelOptions,
  ) : super._() {
    debugPanelOptions.simulateRewardRedemption = simulateRewardRedemption;
    _isConnected = true;
  }
}
