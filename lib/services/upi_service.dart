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
    // Build URI string manually — Flutter's Uri() class adds extra encoding
    // that causes GPay/PhonePe/Paytm to reject or show errors
    final params = <String, String>{
      'pa': upiId,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'mode': '00', // default mode
      if (note != null && note.isNotEmpty) 'tn': note,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final uriString = 'upi://pay?$query';
    final uri = Uri.parse(uriString);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
