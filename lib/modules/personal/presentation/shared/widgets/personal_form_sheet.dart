import 'package:flutter/material.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

/// Matches the add/edit transaction sheets in Personal.
class PersonalFormSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const PersonalFormSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            labelStyle: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: .5),
            ),
            helperMaxLines: 3,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
          ),
          listTileTheme: theme.listTileTheme.copyWith(
            contentPadding: EdgeInsets.zero,
            titleTextStyle: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: .5),
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(icon, size: 24, color: cs.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
