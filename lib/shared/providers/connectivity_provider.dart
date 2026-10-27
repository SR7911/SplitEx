import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  Timer? _timer;

  ConnectivityNotifier() : super(ConnectivityStatus.online) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        state = ConnectivityStatus.online;
      } else {
        state = ConnectivityStatus.offline;
      }
    } catch (_) {
      state = ConnectivityStatus.offline;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
