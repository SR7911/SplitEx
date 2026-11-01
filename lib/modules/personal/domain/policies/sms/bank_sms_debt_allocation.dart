import '../../entities/transactions/personal_transaction.dart';
import '../../repositories/bank_sms_repository.dart';

/// Applies a bank payment in the selected priority order, in paise.
List<BankSmsDebtAllocation> allocateBankSmsDebtPayment(
  Iterable<PersonalTransaction> selectedDebts,
  int amountMinor,
) {
  if (amountMinor <= 0) throw StateError('Payment amount must be positive.');
  final debts = selectedDebts.toList();
  if (debts.isEmpty) throw StateError('Choose at least one debt.');
  final person = normalizedDebtPerson(debts.first.personName);
  if (person.isEmpty ||
      debts.any((debt) => normalizedDebtPerson(debt.personName) != person) ||
      debts.map((debt) => debt.id).toSet().length != debts.length) {
    throw StateError('Choose distinct debts for the same person.');
  }
  final allocations = <BankSmsDebtAllocation>[];
  var allocated = 0;
  for (final debt in debts) {
    if (debt.isSettled) throw StateError('A selected debt is already settled.');
    final available = (debt.remainingAmount * 100).round();
    final remaining = amountMinor - allocated;
    if (remaining <= 0) {
      throw StateError('Payment is fully used. Deselect extra debts.');
    }
    if (available <= 0) throw StateError('A selected debt has no balance.');
    final applied = remaining < available ? remaining : available;
    allocations.add(
      BankSmsDebtAllocation(debtId: debt.id, amountMinor: applied),
    );
    allocated += applied;
  }
  if (allocated != amountMinor) {
    throw StateError('Allocated amounts must equal the full bank payment.');
  }
  return allocations;
}

String normalizedDebtPerson(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
