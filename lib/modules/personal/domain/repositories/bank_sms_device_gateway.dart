/// Boundary to the Android bank-message queue and settings.
abstract interface class BankSmsDeviceGateway {
  bool get supported;
  void setEventHandler(Future<void> Function(String method)? handler);
  Future<void> bindUser(String? userId);
  Future<Map<String, dynamic>> status();
  Future<List<Map<String, dynamic>>> queue(String userId);
  Future<void> requestPermission();
  Future<void> requestRcsAccess();
  Future<void> setRcsEnabled(String? userId, bool enabled);
  Future<String?> consumeShare(String userId);
  Future<void> putReview(String userId, Map<String, dynamic> review);
  Future<void> configure(String? userId, bool enabled, bool autoRecord);
  Future<void> trust(String? userId, String sender, bool trusted);
  Future<void> deleteReview(String? userId, String messageId);
  Future<void> acknowledge(String userId, String messageId);
  Future<void> backgroundComplete(bool retry);
}

class BankSmsDeviceException implements Exception {
  const BankSmsDeviceException();
}
