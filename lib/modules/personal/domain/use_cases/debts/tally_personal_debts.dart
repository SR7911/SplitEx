import '../../repositories/personal_transaction_repository.dart';

class TallyPersonalDebts {
  final PersonalTransactionRepository _repository;
  const TallyPersonalDebts(this._repository);

  Future<void> call(
    String userId,
    String personName, {
    int? expectedOffsetCents,
    int? expectedNetCents,
  }) {
    if (personName.trim().isEmpty) {
      throw StateError('Choose a person to tally with.');
    }
    return _repository.tallyDebts(
      userId,
      personName.trim(),
      expectedOffsetCents: expectedOffsetCents,
      expectedNetCents: expectedNetCents,
    );
  }
}
