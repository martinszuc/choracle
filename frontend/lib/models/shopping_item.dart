import 'member.dart';

class ShoppingItem {
  final String id;
  final String name;
  final int quantity;
  final bool purchased;
  final Member createdBy;
  final Member? purchasedBy;
  final String debtOption;
  final String? linkedTransactionId;
  final DateTime createdAt;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.purchased,
    required this.createdBy,
    this.purchasedBy,
    required this.debtOption,
    this.linkedTransactionId,
    required this.createdAt,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        purchased: json['purchased'] as bool,
        createdBy: Member.fromJson(json['created_by'] as Map<String, dynamic>),
        purchasedBy: json['purchased_by'] != null
            ? Member.fromJson(json['purchased_by'] as Map<String, dynamic>)
            : null,
        debtOption: json['debt_option'] as String,
        linkedTransactionId: json['linked_transaction'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
