import 'member.dart';

class Transaction {
  final String id;
  final Member creditor;
  final List<Member> participants;
  final double amount;
  final String description;
  final bool isRecurring;
  final String? recurrenceInterval;
  final DateTime? nextPaymentDate;
  final DateTime? startDate;
  final bool isSettlement;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.creditor,
    required this.participants,
    required this.amount,
    required this.description,
    required this.isRecurring,
    this.recurrenceInterval,
    this.nextPaymentDate,
    this.startDate,
    required this.isSettlement,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        creditor: Member.fromJson(json['creditor'] as Map<String, dynamic>),
        participants: (json['participants'] as List<dynamic>)
            .map((p) => Member.fromJson(p as Map<String, dynamic>))
            .toList(),
        amount: double.parse(json['amount'].toString()),
        description: json['description'] as String? ?? '',
        isRecurring: json['is_recurring'] as bool,
        recurrenceInterval: json['recurrence_interval'] as String?,
        nextPaymentDate: json['next_payment_date'] != null
            ? DateTime.parse(json['next_payment_date'] as String)
            : null,
        startDate: json['start_date'] != null
            ? DateTime.parse(json['start_date'] as String)
            : null,
        isSettlement: json['is_settlement'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
