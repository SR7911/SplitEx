class SplitCalculator {
  /// Dynamic room splits include the payer while at least one roommate is
  /// selected. Removing one roommate must not silently remove the payer too.
  static List<String> updateDynamicParticipants({
    required List<String> selected,
    required String payerId,
    required String memberId,
    required bool included,
  }) {
    final others = selected.where((id) => id != payerId).toSet();
    if (included) {
      others.add(memberId);
    } else {
      others.remove(memberId);
    }
    return others.isEmpty ? [] : [payerId, ...others];
  }

  static double equalSplit(double amount, int memberCount) {
    if (memberCount <= 0) return 0;
    return amount / memberCount;
  }

  static Map<String, double> dynamicSplit(
    double amount,
    List<String> selectedMembers,
  ) {
    if (selectedMembers.isEmpty) return {};
    final perPerson = amount / selectedMembers.length;
    return {for (final id in selectedMembers) id: perPerson};
  }

  static Map<String, double> oneToOneSplit(
    double amount,
    String fromUser,
    String toUser,
  ) {
    return {fromUser: -amount, toUser: amount};
  }
}
