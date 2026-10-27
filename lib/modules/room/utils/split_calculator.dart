class SplitCalculator {
  static double equalSplit(double amount, int memberCount) {
    if (memberCount <= 0) return 0;
    return amount / memberCount;
  }

  static Map<String, double> dynamicSplit(
      double amount, List<String> selectedMembers) {
    if (selectedMembers.isEmpty) return {};
    final perPerson = amount / selectedMembers.length;
    return {for (final id in selectedMembers) id: perPerson};
  }

  static Map<String, double> oneToOneSplit(
      double amount, String fromUser, String toUser) {
    return {fromUser: -amount, toUser: amount};
  }
}
