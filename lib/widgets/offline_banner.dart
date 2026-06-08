import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/providers/connectivity_provider.dart';

class OfflineIndicator extends ConsumerStatefulWidget {
  const OfflineIndicator({super.key});

  @override
  ConsumerState<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends ConsumerState<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectivityProvider);

    if (status == ConnectivityStatus.online) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Opacity(
        opacity: _pulse.value,
        child: child,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
