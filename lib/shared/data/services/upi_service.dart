import 'package:url_launcher/url_launcher.dart';
import 'package:split_ex/shared/domain/services/upi_payment_launcher.dart';

class UpiService implements UpiPaymentLauncher {
  /// Launches UPI payment intent with pre-filled details.
  /// Returns true if launched successfully.
  Future<bool> launchPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) async {
    final params = <String, String>{
      'pa': upiId,
      'pn': payeeName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'mode': '00',
      if (note != null && note.isNotEmpty) 'tn': note,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final uri = Uri.parse('upi://pay?$query');

    try {
      // Skip canLaunchUrl — it returns false for upi:// on Android even when
      // GPay/PhonePe are installed unless the intent query is declared in
      // AndroidManifest. Attempt launch directly and catch failures.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      return launched;
    } catch (_) {
      return false;
    }
  }
}
