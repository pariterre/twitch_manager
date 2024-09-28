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
    return 'userId: $userId, displayName: $displayName, initiator: $initiator, transactionReceipt: $transactionReceipt';
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
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String,
      initiator: map['initiator'] as String,
      transactionReceipt: map['transaction_receipt'] as String? ?? '',
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
    required this.inDevelopment,
  });

  @override
  String toString() {
    return 'sku: $sku, displayName: $displayName, cost: $cost, inDevelopment: $inDevelopment';
  }
}

class Cost {
  final String amount;
  final String type;

  Cost({
    required this.amount,
    required this.type,
  });

  @override
  String toString() {
    return 'amount: $amount, type: $type';
  }
}
