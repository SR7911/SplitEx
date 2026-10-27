import 'package:flutter/material.dart';

/// Returns the standard card BoxDecoration used across all list screens.
BoxDecoration appCardDecoration(BuildContext context, {Color? accentColor}) {
  final cs     = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(AppRadius.xl),
    border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: (accentColor ?? Colors.black).withValues(alpha: isDark ? 0.12 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

/// Centralized spacing and radius scale.
/// Use these instead of arbitrary numeric literals.
class AppSpacing {
  AppSpacing._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 40;
}

class AppRadius {
  AppRadius._();

  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;
}
