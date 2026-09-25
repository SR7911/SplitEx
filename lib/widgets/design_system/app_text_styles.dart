import 'package:flutter/material.dart';

/// Centralized typography helpers.
/// All styles are derived from [Theme] — no hardcoded colors.
class AppTextStyles {
  AppTextStyles._();

  /// 28px w700 — large page hero title
  static TextStyle pageTitle(BuildContext context) =>
      TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 20px w700 — screen / section title
  static TextStyle sectionTitle(BuildContext context) =>
      TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 14px w600 — section header label
  static TextStyle sectionHeader(BuildContext context) =>
      TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 15px w400 — primary body text
  static TextStyle body(BuildContext context) =>
      TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 13px w400 — secondary body / list subtitle
  static TextStyle bodySmall(BuildContext context) =>
      TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      );

  /// 11px w400 — captions, timestamps, hints
  static TextStyle caption(BuildContext context) =>
      TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      );

  /// 12px w600 — labels, chips, badges
  static TextStyle label(BuildContext context) =>
      TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 28px w800 — large KPI / stat number
  static TextStyle stat(BuildContext context) =>
      TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 18px w700 — smaller stat number
  static TextStyle statSmall(BuildContext context) =>
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 16px w600 — button / action label
  static TextStyle button(BuildContext context) =>
      TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onPrimary,
      );
}
