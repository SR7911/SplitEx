import 'package:url_launcher/url_launcher.dart';

class UpiService {
  /// Launches UPI payment intent with pre-filled details.
  /// Returns true if launched successfully.
  Future<bool> launchPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) async {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': payeeName,
        'am': amount.toStringAsFixed(2),
        'cu': 'INR',
        if (note != null) 'tn': note,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }
}
