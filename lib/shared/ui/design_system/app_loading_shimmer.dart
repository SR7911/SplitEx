import 'package:flutter/material.dart';
import 'app_spacing.dart';

/// A shimmer-style skeleton placeholder.
/// Use [AppLoadingShimmer.block] for arbitrary rectangles,
/// or compose [AppLoadingShimmer.listTile] for list skeletons.
class AppLoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppLoadingShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppSpacing.md,
  });

  /// A full-width block skeleton
  const AppLoadingShimmer.block({
    super.key,
    this.height = 56,
    this.borderRadius = AppSpacing.lg,
  }) : width = double.infinity;

  @override
  State<AppLoadingShimmer> createState() => _AppLoadingShimmerState();
}

class _AppLoadingShimmerState extends State<AppLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final highlight = cs.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(base, highlight, _animation.value),
        ),
      ),
    );
  }
}

/// A pre-composed list tile skeleton row
class AppLoadingListTile extends StatelessWidget {
  const AppLoadingListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          AppLoadingShimmer(width: 44, height: 44, borderRadius: AppSpacing.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppLoadingShimmer(
                  width: double.infinity,
                  height: 14,
                  borderRadius: AppSpacing.sm,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppLoadingShimmer(
                  width: 120,
                  height: 11,
                  borderRadius: AppSpacing.sm,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppLoadingShimmer(width: 56, height: 14, borderRadius: AppSpacing.sm),
        ],
      ),
    );
  }
}
