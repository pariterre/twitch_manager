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
}

class ExtractedTransactionReceipt {
  int userId;
  BitsProduct product;

  ExtractedTransactionReceipt({
    required this.userId,
    required this.product,
  });

  @override
  String toString() {
    return 'user_id: $userId, product: $product';
  }

  static ExtractedTransactionReceipt fromJson(Map<String, dynamic> map) {
    return ExtractedTransactionReceipt(
      userId: int.tryParse(map['data']['userId'] as String? ?? '') ?? -1,
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

  static Cost fromJson(Map<String, dynamic> map) {
    var amount = map['amount'] ?? -1;
    if (amount is String) {
      amount = int.tryParse(amount) ?? -1;
    }
    return Cost(amount: amount, type: map['type'] as String? ?? '');
  }
}
