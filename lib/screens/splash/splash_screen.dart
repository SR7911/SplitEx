import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_ex/providers/auth_provider.dart';

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

    _controller.forward().then((_) => _navigateToNext());
  }

  Future<void> _navigateToNext() async {
    // Wait for animations and a minimum splash time
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;

    try {
      // Ensure the initial auth state is loaded before deciding where to go
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) {
        await ref.read(authStateProvider.future);
      }
      
      if (!mounted) return;

      // With refreshListenable in router.dart, GoRouter might have already 
      // triggered a redirect if the state was updated. 
      // We perform a manual navigation here as a fallback/kickstart 
      // to move away from the splash screen.
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
