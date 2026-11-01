
enum BillType { rent, electricity, water }

class BillModel {
  final String id;
  final BillType type;
  final double amount;
  final String splitType;
  final String paidBy;
  final List<String> splitAmong;
  final String month;
  final DateTime date;
  final String? receiptUrl;
  final DateTime createdAt;

  const BillModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.splitType,
    required this.paidBy,
    required this.splitAmong,
    required this.month,
    required this.date,
    this.receiptUrl,
    required this.createdAt, 
  });

  String get typeName => switch (type) {
        BillType.rent => 'Rent',
        BillType.electricity => 'Electricity',
        BillType.water => 'Water',
      };

}
