import 'package:flutter/material.dart';

/// Semantic color helpers derived purely from [ColorScheme].
/// Never hardcode hex values — always go through these helpers.
class AppColors {
  AppColors._();

  // ── Semantic status colors ──────────────────────────────────────────────
  // These are fixed semantic meanings but still use Material-compatible values
  // that work on both light and dark surfaces.

  static Color success(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  }

  static Color warning(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  }

  static Color error(BuildContext context) =>
      Theme.of(context).colorScheme.error;

  static Color info(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  // ── Surface helpers ─────────────────────────────────────────────────────

  /// Slightly elevated surface — for cards, containers
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  /// Higher elevation surface — for modals, sheets
  static Color surfaceHigh(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return cs.surfaceContainerHigh;
  }

  /// Subtle tinted surface using primary at low opacity
  static Color primarySurface(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

  /// Subtle success-tinted surface
  static Color successSurface(BuildContext context) =>
      success(context).withValues(alpha: 0.08);

  /// Subtle warning-tinted surface
  static Color warningSurface(BuildContext context) =>
      warning(context).withValues(alpha: 0.08);

  /// Subtle error-tinted surface
  static Color errorSurface(BuildContext context) =>
      Theme.of(context).colorScheme.errorContainer;

  // ── Text helpers ─────────────────────────────────────────────────────────

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

  static Color textTertiary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

  // ── Divider / border ─────────────────────────────────────────────────────

  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color border(BuildContext context) =>
      Theme.of(context).colorScheme.outline.withValues(alpha: 0.15);
}
