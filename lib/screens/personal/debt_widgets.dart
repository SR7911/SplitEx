import 'package:flutter/material.dart';
import 'package:split_ex/widgets/design_system/design_system.dart';

/// Matches the section cards on the Personal Expenses overview.
BoxDecoration debtCardDecoration(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outline.withValues(alpha: .08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? .15 : .04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

class DebtSectionCard extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  final List<Widget> children;
  const DebtSectionCard({
    super.key,
    required this.title,
    required this.onViewAll,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: debtCardDecoration(context),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: 'View All',
          onAction: onViewAll,
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    ),
  );
}

/// A compact tinted row, following Recent Transactions in Personal Expenses.
class DebtInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String? detail;
  final Color? color;
  final VoidCallback? onTap;
  const DebtInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onTap,
    this.detail,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = color ?? cs.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: dark ? .07 : .04),
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
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail!,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared modal presentation used for debt lists, categories and people.
class DebtSheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final int? itemCount;
  final double extraContentHeight;
  const DebtSheetFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.itemCount,
    this.extraContentHeight = 0,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: itemCount == null
          ? .85
          : ((158 + itemCount! * 92 + extraContentHeight) /
                    MediaQuery.sizeOf(context).height)
                .clamp(.32, .85),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 18),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: .5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline.withValues(alpha: .08)),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
