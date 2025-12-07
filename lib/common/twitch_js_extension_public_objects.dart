import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

///
/// This is the object returned when a transaction is completed
class BitsTransactionObject {
  final String userId;
  final String displayName;
  final String initiator;
  final String transactionReceipt;

  BitsTransactionObject({
    required this.userId,
    required this.displayName,
    required this.initiator,
    required this.transactionReceipt,
  });

  @override
  String toString() {
    return 'userId: $userId, display_name: $displayName, initiator: $initiator, transaction_receipt: $transactionReceipt';
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'initiator': initiator,
      'transaction_receipt': transactionReceipt,
    };
  }

  static BitsTransactionObject fromJson(Map<String, dynamic> map) {
    return BitsTransactionObject(
      userId: map['user_id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      initiator: map['initiator'] as String? ?? '',
      transactionReceipt: map['transaction_receipt'] as String? ?? '',
    );
  }

  static BitsTransactionObject generateMocked({
    required String userId,
    required String sku,
    String displayName = 'MockedDisplayName',
    String initiator = 'MockedInitiator',
    required String sharedSecret,
  }) {
    return BitsTransactionObject(
        userId: userId,
        displayName: displayName,
        initiator: initiator,
        transactionReceipt: JWT(ExtractedTransactionReceipt(
          userId: userId,
          product: BitsProduct(
            sku: sku,
            displayName: 'MockedDisplayName',
            cost: Cost(amount: -1, type: 'mocked'),
          ),
        ).toJson())
            .sign(SecretKey(sharedSecret, isBase64Encoded: true)));
  }
}

class ExtractedTransactionReceipt {
  String userId;
  BitsProduct product;

  ExtractedTransactionReceipt({
    required this.userId,
    required this.product,
  });

  @override
  String toString() {
    return 'user_id: $userId, product: $product';
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {'userId': userId, 'product': product.toJson()}
    };
  }

  static ExtractedTransactionReceipt fromJson(Map<String, dynamic> map) {
    return ExtractedTransactionReceipt(
      userId: map['data']['userId'] as String? ?? '',
      product:
          BitsProduct.fromJson(map['data']['product'] as Map<String, dynamic>),
    );
  }
}

class BitsProduct {
  final String sku;
  final String displayName;
  final Cost cost;
  final bool inDevelopment;

  BitsProduct({
    required this.sku,
    required this.displayName,
    required this.cost,
    this.inDevelopment = false,
  });

  @override
  String toString() {
    return 'sku: $sku, display_name: $displayName, cost: $cost, in_development: $inDevelopment';
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'displayName': displayName,
      'cost': cost.toJson(),
      'inDevelopment': inDevelopment,
    };
  }

  static BitsProduct fromJson(Map<String, dynamic> map) {
    return BitsProduct(
      sku: map['sku'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      cost: Cost.fromJson(map['cost'] as Map<String, dynamic>),
      inDevelopment: map['inDevelopment'] as bool? ?? false,
    );
  }
}

class Cost {
  final int amount;
  final String type;

  Cost({
    required this.amount,
    required this.type,
  });

  @override
  String toString() {
    return 'amount: $amount, type: $type';
  }

  Map<String, dynamic> toJson() {
    return {'amount': amount, 'type': type};
  }

  static Cost fromJson(Map<String, dynamic> map) {
    var amount = map['amount'] ?? -1;
    if (amount is String) {
      amount = int.tryParse(amount) ?? -1;
    }
    return Cost(amount: amount, type: map['type'] as String? ?? '');
  }
}
