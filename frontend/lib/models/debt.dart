class Debt {
  final String debtorId;
  final String debtorName;
  final String debtorColor;
  final String creditorId;
  final String creditorName;
  final String creditorColor;
  final double amount;

  const Debt({
    required this.debtorId,
    required this.debtorName,
    required this.debtorColor,
    required this.creditorId,
    required this.creditorName,
    required this.creditorColor,
    required this.amount,
  });

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        debtorId: json['debtor_id'] as String,
        debtorName: json['debtor_name'] as String,
        debtorColor: json['debtor_color'] as String,
        creditorId: json['creditor_id'] as String,
        creditorName: json['creditor_name'] as String,
        creditorColor: json['creditor_color'] as String,
        amount: double.parse(json['amount'].toString()),
      );
}
