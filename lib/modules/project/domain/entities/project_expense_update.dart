import 'project_model.dart';

class ProjectExpenseUpdate {
  final String title;
  final double amount;
  final String category;
  final String? vendor;
  final String? notes;
  final PaymentMethod paymentMethod;
  final DateTime date;
  final ProjectDebtType? debtType;
  final String? personName;
  final bool isSettled;

  const ProjectExpenseUpdate({
    required this.title,
    required this.amount,
    required this.category,
    this.vendor,
    this.notes,
    required this.paymentMethod,
    required this.date,
    this.debtType,
    this.personName,
    required this.isSettled,
  });
}
