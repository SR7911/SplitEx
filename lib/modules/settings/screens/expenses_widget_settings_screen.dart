import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/settings/providers/expenses_widget_settings_provider.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/modules/settings/widgets/dot_matrix_label.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';

class ExpensesWidgetSettingsScreen extends ConsumerWidget {
  const ExpensesWidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(expensesWidgetSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    void update(ExpensesWidgetSettings next) {
      ref.read(expensesWidgetSettingsProvider.notifier).update(next);
    }

    return Scaffold(
      appBar: const AppHeader(
        showBack: true,
        title: 'Home Screen Widget',
        showNotification: false,
      ),
      body: GradientBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.xl,
          ),
          children: [
            // Preview card
            ExpensesWidgetPreview(settings: settings),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sample preview · Applies to all My Expenses widgets',
              style: AppTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Style section
            _SectionLabel('Style'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: appCardDecoration(context),
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Widget style', style: AppTextStyles.sectionHeader(context)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choose between a minimal dot-matrix look or a vibrant gradient card.',
                    style: AppTextStyles.bodySmall(context),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'nothing',
                        icon: Icon(Icons.grid_on_rounded, size: 16),
                        label: Text('Nothing'),
                      ),
                      ButtonSegment(
                        value: 'hero',
                        icon: Icon(Icons.gradient_rounded, size: 16),
                        label: Text('Hero gradient'),
                      ),
                    ],
                    selected: {settings.style},
                    onSelectionChanged: (v) => update(settings.copyWith(style: v.first)),
                  ),
                ],
              ),
            ),

            // Appearance — only for Nothing style
            if (settings.style == 'nothing') ...[
              const SizedBox(height: AppSpacing.base),
              _SectionLabel('Appearance'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: appCardDecoration(context),
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Color tone', style: AppTextStyles.sectionHeader(context)),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'dark',
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                          label: Text('Black'),
                        ),
                        ButtonSegment(
                          value: 'light',
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                          label: Text('White'),
                        ),
                        ButtonSegment(
                          value: 'system',
                          icon: Icon(Icons.brightness_auto_rounded, size: 16),
                          label: Text('System'),
                        ),
                      ],
                      selected: {settings.tone},
                      onSelectionChanged: (v) => update(settings.copyWith(tone: v.first)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SettingSwitch(
                      icon: Icons.grain_rounded,
                      title: 'Grey dot texture',
                      subtitle: 'Subtle pattern behind the card',
                      value: settings.dots,
                      onChanged: (v) => update(settings.copyWith(dots: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.circle_rounded,
                      title: 'Red accents',
                      subtitle: 'Highlight the add button and overspending',
                      value: settings.redAccent,
                      color: cs.error,
                      onChanged: (v) => update(settings.copyWith(redAccent: v)),
                    ),
                  ],
                ),
              ),
            ],

            // Display section
            const SizedBox(height: AppSpacing.base),
            _SectionLabel('Display'),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: appCardDecoration(context),
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  _SettingSwitch(
                    icon: Icons.visibility_off_rounded,
                    title: 'Hide amounts',
                    subtitle: 'Mask amounts and spending progress on the home screen',
                    value: settings.hideAmounts,
                    onChanged: (v) => update(settings.copyWith(hideAmounts: v)),
                  ),
                  _SettingSwitch(
                    icon: Icons.numbers_rounded,
                    title: 'Show paise',
                    subtitle: 'Off rounds display amounts to the nearest rupee',
                    value: settings.decimals,
                    onChanged: (v) => update(settings.copyWith(decimals: v)),
                  ),
                  _SettingSwitch(
                    icon: Icons.linear_scale_rounded,
                    title: 'Spending progress',
                    subtitle: 'Show expenses as a share of income',
                    value: settings.progress,
                    onChanged: (v) => update(settings.copyWith(progress: v)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.base),
            // Info hint
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Changes save automatically. Add the widget from your Android home screen\'s widget picker.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color? color;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 18, color: effectiveColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                Text(subtitle, style: AppTextStyles.caption(context)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: effectiveColor,
          ),
        ],
      ),
    );
  }
}

// ── Widget Preview ─────────────────────────────────────────────────────────

class ExpensesWidgetPreview extends StatelessWidget {
  final ExpensesWidgetSettings settings;
  const ExpensesWidgetPreview({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final nothing = settings.style == 'nothing';
    final dark =
        settings.tone == 'dark' ||
        (settings.tone == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final foreground = nothing && !dark ? const Color(0xFF141414) : Colors.white;
    final muted = nothing
        ? (dark ? const Color(0xFFE0E0E0) : const Color(0xFF333333))
        : foreground.withValues(alpha: .6);
    final accent = nothing && settings.redAccent ? const Color(0xFFCC2222) : foreground;
    final value = settings.hideAmounts
        ? '••••'
        : settings.decimals
        ? '₹10,000.00'
        : '₹10,000';
    final colors = AppTheme.financialHeroColors(
      isPositive: false,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    Widget matrixText(String value, {TextStyle? style}) => nothing
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DotMatrixLabel(
              text: value,
              color: style?.color ?? foreground,
              fontSize: style?.fontSize ?? 14,
            ),
          )
        : Text(value, style: style);

    Widget stat(String label, String amount) => Expanded(
      child: Container(
        padding: nothing
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: nothing
            ? null
            : BoxDecoration(
                color: foreground.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            matrixText(label, style: TextStyle(color: muted, fontSize: 10)),
            matrixText(
              settings.hideAmounts ? '••••' : '$amount${settings.decimals ? '.00' : ''}',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: nothing ? 15 : 17,
              ),
            ),
          ],
        ),
      ),
    );

    if (nothing) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: dark ? const Color(0xFF101010) : const Color(0xFFF5F5F5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  DotMatrixLabel(color: foreground, fontSize: 11),
                  const Spacer(),
                  matrixText('OCT 2026', style: TextStyle(color: muted, fontSize: 10)),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      matrixText(
                        settings.hideAmounts ? 'Monthly balance' : 'Overspent by',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      matrixText(value, style: TextStyle(color: accent, fontSize: 32)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: settings.redAccent ? accent : foreground,
                    ),
                    alignment: Alignment.center,
                    child: matrixText(
                      '+',
                      style: TextStyle(
                        fontSize: 22,
                        color: settings.redAccent
                            ? Colors.white
                            : dark
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  stat('↓ Income', '₹20,000'),
                  const SizedBox(width: 16),
                  stat('↑ Spent', '₹30,000'),
                ]),
                const SizedBox(height: 14),
                if (settings.progress && !settings.hideAmounts) ...[
                  DotMatrixProgress(
                    value: 1,
                    color: accent,
                    trackColor: dark ? const Color(0xFF505050) : const Color(0xFFB8B8B8),
                  ),
                  const SizedBox(height: 6),
                ],
                matrixText(
                  settings.hideAmounts
                      ? 'Amounts hidden'
                      : settings.progress
                      ? '150.0% of income spent'
                      : 'Income minus expenses',
                  style: TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
        ),
        child: CustomPaint(
          painter: settings.dots ? _DotTexture(foreground.withValues(alpha: .12)) : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    matrixText(
                      'My Expenses',
                      style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    matrixText('OCT 2026', style: TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          matrixText(
                            settings.hideAmounts ? 'Monthly balance' : 'Overspent by',
                            style: TextStyle(color: muted, fontSize: 11),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: matrixText(
                              value,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 34,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .16),
                      ),
                      alignment: Alignment.center,
                      child: matrixText(
                        '+',
                        style: const TextStyle(color: Colors.white, fontSize: 28),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    stat('↓ Income', '₹20,000'),
                    const SizedBox(width: 8),
                    stat('↑ Spent', '₹30,000'),
                  ],
                ),
                const SizedBox(height: 8),
                if (settings.progress && !settings.hideAmounts) ...[
                  LinearProgressIndicator(
                    value: 1,
                    minHeight: 3,
                    color: accent,
                    backgroundColor: muted.withValues(alpha: .15),
                  ),
                  const SizedBox(height: 4),
                ],
                matrixText(
                  settings.hideAmounts
                      ? 'Amounts hidden'
                      : settings.progress
                      ? '150.0% of income spent'
                      : 'Income minus expenses',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotTexture extends CustomPainter {
  final Color color;
  _DotTexture(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = size.width * .7; x < size.width; x += 8) {
      for (double y = 0; y < size.height; y += 8) {
        canvas.drawCircle(Offset(x, y), .7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotTexture oldDelegate) => color != oldDelegate.color;
}
