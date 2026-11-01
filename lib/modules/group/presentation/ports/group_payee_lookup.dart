abstract interface class GroupPayeeLookup {
  Future<String?> upiIdFor(String userId);
}
