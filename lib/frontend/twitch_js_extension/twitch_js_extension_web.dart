import 'dart:js_interop';

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
@staticInterop
class _TwitchExtension {}

extension on _TwitchExtension {
  external void onAuthorized(JSFunction callback);

  // Listen to PubSub messages
  external void listen(String target, JSFunction callback);
}

///
/// Define the response from the Twitch Extension onAuthorized callback
@JS()
@anonymous
@staticInterop
class _OnAuthorizedResponseJs {}

extension on _OnAuthorizedResponseJs {
  external String get channelId;
  external String get clientId;
  external String get token;
  external String get helixToken;
  external String get userId;
}

///
/// Define an interface to call the Twitch Extension JavaScript API
class TwitchJsExtensionWeb implements TwitchJsExtensionBase {
  @override
  void onAuthorized(Function(OnAuthorizedResponse auth) callback) {
    _twitchExtension.onAuthorized(((JSAny jsObj) {
      final auth = jsObj as _OnAuthorizedResponseJs;
      callback(OnAuthorizedResponse(
        channelId: auth.channelId,
        clientId: auth.clientId,
        token: auth.token,
        helixToken: auth.helixToken,
        userId: auth.userId,
      ));
    }).toJS);
  }

  @override
  void listen(String target,
      Function(String target, String contentType, String message) callback) {
    _twitchExtension.listen(
        target,
        ((JSAny target, JSAny contentType, JSAny message) {
          callback(target as String, contentType as String, message as String);
        }).toJS);
  }
}

@JS('Twitch.ext.actions')
external _TwitchActions get _twitchActions;

@JS()
@staticInterop
class _TwitchActions {}

extension on _TwitchActions {
  external void requestIdShare();
}

class TwitchJsExtensionActionsWeb implements TwitchJsExtensionActionsBase {
  @override
  void requestIdShare() => _twitchActions.requestIdShare();
}

@JS('Twitch.ext.bits')
external _TwitchBits get _twitchBits;

@JS()
@staticInterop
class _TwitchBits {}

extension on _TwitchBits {
  external JSPromise getProducts();
  external void onTransactionComplete(JSFunction callback);
  external void onTransactionCancelled(JSFunction callback);
  external void setUseLoopback(bool useLoopBack);
  external void useBits(String sku);
}

@JS()
@anonymous
@staticInterop
class _BitsProductJs {}

extension on _BitsProductJs {
  external String get sku;
  external String get displayName;
  external bool get inDevelopment;
  external _BitsCostJs get cost;
}

@JS()
@anonymous
@staticInterop
class _BitsCostJs {}

extension on _BitsCostJs {
  external String get amount;
  external String get type;
}

@JS()
@anonymous
@staticInterop
class _BitsTransactionObjectJs {}

extension on _BitsTransactionObjectJs {
  external String get userId;
  external String get displayName;
  external int get initiator;
  external String get transactionReceipt;
}

class TwitchJsExtensionBitsWeb implements TwitchJsExtensionBitsBase {
  TwitchJsExtensionBitsWeb() {
    _twitchBits.onTransactionComplete(((JSAny transaction) {
      _handleOnTransactionCompleted(transaction as _BitsTransactionObjectJs);
    }).toJS);

    _twitchBits.onTransactionCancelled((() {
      _handleOnTransactionCancelled();
    }).toJS);
  }

  @override
  Future<List<BitsProduct>> getProducts() async {
    final jsArray = await _twitchBits.getProducts().toDart as JSArray;
    return jsArray.toDart
        .cast<_BitsProductJs>()
        .map((jsProduct) => BitsProduct(
              sku: jsProduct.sku,
              displayName: jsProduct.displayName,
              inDevelopment: jsProduct.inDevelopment,
              cost: Cost(
                amount: int.tryParse(jsProduct.cost.amount) ?? -1,
                type: jsProduct.cost.type,
              ),
            ))
        .toList();
  }

  final _onTransactionCompleted =
      TwitchListener<Function(BitsTransactionObject)>();
  @override
  TwitchListener<Function(BitsTransactionObject)> get onTransactionCompleted =>
      _onTransactionCompleted;

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

  void _handleOnTransactionCancelled() {
    _onTransactionCancelled.notifyListeners((callback) => callback());
  }

  @override
  void setUseLoopback(bool useLoopBack) {
    _twitchBits.setUseLoopback(useLoopBack);
  }

  @override
  void useBits(String sku) {
    _twitchBits.useBits(sku);
  }
}

@JS('Twitch.ext.viewer')
external _TwitchViewer get _twitchViewer;

@JS()
@staticInterop
class _TwitchViewer {}

extension on _TwitchViewer {
  external String get opaqueId;
  external String? get id;
}

class TwitchJsExtensionViewerWeb implements TwitchJsExtensionViewerBase {
  @override
  String get opaqueId => _twitchViewer.opaqueId;

  @override
  String? get id => _twitchViewer.id;
}

final TwitchJsExtensionWeb _instance = TwitchJsExtensionWeb();
TwitchJsExtensionBase get getTwitchJsExtension => _instance;

final TwitchJsExtensionActionsBase _actionsInstance =
    TwitchJsExtensionActionsWeb();
TwitchJsExtensionActionsBase get getTwitchJsExtensionActions =>
    _actionsInstance;

final TwitchJsExtensionBitsBase _bitsInstance = TwitchJsExtensionBitsWeb();
TwitchJsExtensionBitsBase get getTwitchJsExtensionBits => _bitsInstance;

final TwitchJsExtensionViewerBase _viewerInstance =
    TwitchJsExtensionViewerWeb();
TwitchJsExtensionViewerBase get getTwitchJsExtensionViewer => _viewerInstance;
