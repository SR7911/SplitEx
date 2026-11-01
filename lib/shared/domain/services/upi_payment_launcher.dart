abstract interface class UpiPaymentLauncher {
  Future<bool> launchPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  });
}
