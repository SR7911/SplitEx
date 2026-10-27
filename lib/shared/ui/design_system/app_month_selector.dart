import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// A consistent month navigation row used across all screens.
///
/// ```
///  ‹   January 2025  [Current]   ›
/// ```
class AppMonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const AppMonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPrev,
    required this.onNext,
  });

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                style: AppTextStyles.sectionHeader(context),
              ),
              if (_isCurrentMonth) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.lg),
                  ),
                  child: Text(
                    'Now',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: _isCurrentMonth ? null : onNext,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? cs.onSurface.withValues(alpha: 0.7)
              : cs.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
