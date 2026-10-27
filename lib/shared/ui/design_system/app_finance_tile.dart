import 'package:flutter/material.dart';
import 'app_spacing.dart';

/// The compact row used by the Personal dashboard's transaction lists.
class AppFinanceTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? value, detail;
  final Color? color, valueColor;
  final Widget? leading, action, badges;
  final VoidCallback? onTap;
  const AppFinanceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.detail,
    this.color,
    this.valueColor,
    this.leading,
    this.action,
    this.badges,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = color ?? cs.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha: theme.brightness == Brightness.dark ? .07 : .04,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: .12)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: leading ?? Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: .5),
                      ),
                    ),
                    if (badges != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      badges!,
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value!,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: valueColor ?? accent,
                          ),
                        ),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          detail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: .5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(width: AppSpacing.xs),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppFinanceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const AppFinanceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              icon,
              size: 26,
              color: cs.onSurface.withValues(alpha: .3),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }
}
