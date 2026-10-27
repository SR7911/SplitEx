import 'package:flutter/material.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// A compact stat tile: icon → value → label.
/// Color is passed in — caller decides semantic meaning.
/// Background and border are derived from that color at low opacity.
class AppStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const AppStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.base,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.sm + 2),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            value,
            style: AppTextStyles.statSmall(context).copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption(context)),
        ],
      ),
    );
  }
}
