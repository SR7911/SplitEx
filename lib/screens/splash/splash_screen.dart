import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/services/app_update_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _controller.forward().then((_) => _checkUpdateAndNavigate());
  }

  Future<void> _checkUpdateAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final updateInfo = await AppUpdateService.checkForUpdate();

    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    } else {
      _navigateToNext();
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(
        info: info,
        onSkip: info.isMandatory ? null : () {
          Navigator.of(ctx).pop();
          _navigateToNext();
        },
      ),
    );
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    try {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) {
        await ref.read(authStateProvider.future);
      }

      if (!mounted) return;

      final user = ref.read(authStateProvider).valueOrNull;

      if (user == null) {
        context.go('/login');
      } else {
        final profileExists = await ref.read(profileExistsProvider.future);
        if (mounted) {
          context.go(profileExists ? '/' : '/profile-setup');
        }
      }
    } catch (e) {
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/app_icon.png',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SplitEx',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontFamily: 'Gilmer',
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  final VoidCallback? onSkip;

  const _UpdateDialog({required this.info, this.onSkip});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _error = null; _progress = 0; });
    try {
      await AppUpdateService.downloadAndInstall(
        widget.info.downloadUrl,
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (e) {
      final msg = e.toString().contains('timeout')
          ? 'Connection timed out. Check your internet and try again.'
          : 'Download failed. Please check your connection and try again.';
      if (mounted) setState(() { _error = msg; _downloading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.isMandatory,
      child: AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A new version of SplitEx is available. Please update to continue.'),
            if (_downloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}%'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (widget.onSkip != null && !_downloading)
            TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
          if (!_downloading)
            FilledButton(onPressed: _startDownload, child: const Text('Update'))
          else if (_error != null)
            FilledButton(onPressed: _startDownload, child: const Text('Retry')),
        ],
      ),
    );
  }
}
