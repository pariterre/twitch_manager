// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_interface.dart';
import 'package:twitch_manager/frontend/twitch_js_extension/twitch_js_extension_public_objects.dart';
import 'package:twitch_manager/twitch_utils.dart';

///
/// Reference for the Twitch Extension JavaScript API
/// https://dev.twitch.tv/docs/extensions/reference/

///
/// Declare external JavaScript function and objects
@JS('Twitch.ext')
external _TwitchExtension get _twitchExtension;

///
/// Define the Twitch Extension JavaScript API
@JS()
@anonymous
class _TwitchExtension {
  external void onAuthorized(Function(_OnAuthorizedResponseJs auth) callback);

  // Listen to PubSub messages
  external void listen(
    String target,
    Function(String target, String contentType, String message) callback,
  );
}

///
/// Define the response from the Twitch Extension onAuthorized callback
@JS()
@anonymous
class _OnAuthorizedResponseJs {
  external String get channelId;
  external String get clientId;
  external String get token;
  external String get helixToken;
  external String get userId;
}

OnAuthorizedResponse _fromReponseJsToReponse(
    _OnAuthorizedResponseJs responseJs) {
  return OnAuthorizedResponse(
    channelId: responseJs.channelId,
    clientId: responseJs.clientId,
    token: responseJs.token,
    helixToken: responseJs.helixToken,
    userId: responseJs.userId,
  );
}

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJsExtensionWeb implements TwitchJsExtensionBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    _twitchExtension.onAuthorized(allowInterop(
        (responseJs) => callback(_fromReponseJsToReponse(responseJs))));
  }

  @override
  void listen(String target,
      Function(String target, String contentType, String message) callback) {
    _twitchExtension.listen(target, allowInterop(callback));
  }
}

@JS('Twitch.ext.actions')
external _TwitchActions get _twitchActions;

@JS()
@anonymous
class _TwitchActions {
  external void requestIdShare();
}

class TwitchJsExtensionActionWeb implements TwitchJsExtensionActionsBase {
  @override
  void requestIdShare() => _twitchActions.requestIdShare();
}

@JS('Twitch.ext.bits')
external _TwitchBits get _twitchBits;

@JS()
@anonymous
class _BitsTransactionObjectJs {
  external String get userId;
  external String get displayName;
  external int get initiator;
  external String get transactionReceipt;
}

@JS()
@anonymous
class _TwitchBits {
  external dynamic getProducts();
  external void onTransactionComplete(
      Function(_BitsTransactionObjectJs transaction) callback);
  external void onTransactionCancelled(Function() callback);
  external void setUseLoopback(bool useLoopBack);
  external void useBits(String sku);
}

// Factory constructor to create a Product from a Dart map
BitsProduct _bitsProductFromJsMap(Map<String, dynamic> map) => BitsProduct(
      sku: map['sku'] as String,
      displayName: map['displayName'] as String,
      cost: _costFromJsMap(
          Map<String, dynamic>.from(dartify(map['cost']) as Map)),
      inDevelopment: map['inDevelopment'] as bool,
    );

// Factory constructor to create a Cost object from a Dart map
_costFromJsMap(Map<String, dynamic> map) => Cost(
      amount: map['amount'] as String,
      type: map['type'] as String,
    );

class TwitchJsExtensionBitsWeb implements TwitchJsExtensionBitsBase {
  ///
  /// Constructor
  TwitchJsExtensionBitsWeb() {
    _twitchBits.onTransactionComplete(allowInterop(
        (transactionJs) => _handleOnTransactionCompleted(transactionJs)));
    _twitchBits.onTransactionCancelled(
        allowInterop(() => _handleOnTransactionCancelled()));
  }

  @override
  Future<List<BitsProduct>> getProducts() async {
    // Convert the JS Promise to a Dart Future
    List jsList = await promiseToFuture(_twitchBits.getProducts());

    // Convert the JS objects to Dart objects
    return jsList
        .map((item) => _bitsProductFromJsMap(
            Map<String, dynamic>.from(dartify(item) as Map)))
        .toList();
  }

  final _onTransactionCompleted =
      TwitchListener<Function(BitsTransactionObject)>();
  @override
  TwitchListener<Function(BitsTransactionObject p1)>
      get onTransactionCompleted => _onTransactionCompleted;
  void _handleOnTransactionCompleted(_BitsTransactionObjectJs transactionJs) {
    final transaction = BitsTransactionObject(
        userId: transactionJs.userId,
        displayName: transactionJs.displayName,
        initiator: transactionJs.initiator == 0 ? 'current_user' : 'other',
        transactionReceipt: transactionJs.transactionReceipt);

    _onTransactionCompleted
        .notifyListeners((callback) => callback(transaction));
  }

  final _onTransactionCancelled = TwitchListener<Function()>();
  @override
  TwitchListener<Function()> get onTransactionCancelled =>
      _onTransactionCancelled;
  void _handleOnTransactionCancelled() =>
      _onTransactionCancelled.notifyListeners((callback) => callback());

  @override
  void setUseLoopback(bool useLoopBack) {
    _twitchBits.setUseLoopback(useLoopBack);
  }

  @override
  void useBits(String sku) => _twitchBits.useBits(sku);
}

final TwitchJsExtensionWeb _instance = TwitchJsExtensionWeb();
TwitchJsExtensionBase get getTwitchJsExtension => _instance;

final TwitchJsExtensionActionsBase _actionsInstance =
    TwitchJsExtensionActionWeb();
TwitchJsExtensionActionsBase get getTwitchJsExtensionActions =>
    _actionsInstance;

final TwitchJsExtensionBitsBase _bitsInstance = TwitchJsExtensionBitsWeb();
TwitchJsExtensionBitsBase get getTwitchJsExtensionBits => _bitsInstance;
