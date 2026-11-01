import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/services/upi_payment_launcher.dart';

final upiServiceProvider = Provider<UpiPaymentLauncher>(
  (ref) => throw StateError('UPI payment launcher is not configured.'),
);
