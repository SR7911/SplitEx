import 'package:flutter/material.dart';

/// Shared quick-action tile — icon circle + label, no card background.
/// Sits cleanly on any gradient or surface background.
class AppQuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const AppQuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3), width: 1.5),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
