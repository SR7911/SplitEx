import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/shared/ui/theme.dart';
import 'package:split_ex/modules/settings/providers/expenses_widget_settings_provider.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';
import 'package:split_ex/modules/settings/widgets/dot_matrix_label.dart';

class ExpensesWidgetSettingsScreen extends ConsumerWidget {
  const ExpensesWidgetSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(expensesWidgetSettingsProvider);
    void update(ExpensesWidgetSettings next) {
      ref.read(expensesWidgetSettingsProvider.notifier).update(next);
    }

    return Scaffold(
      appBar: const AppHeader(
        showBack: true,
        title: 'Home screen widget',
        showNotification: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ExpensesWidgetPreview(settings: settings),
          const SizedBox(height: 8),
          const Text(
            'Sample preview · Applies to all My Expenses widgets',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text('Style', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'nothing', label: Text('Nothing')),
              ButtonSegment(value: 'hero', label: Text('Hero gradient')),
            ],
            selected: {settings.style},
            onSelectionChanged: (value) =>
                update(settings.copyWith(style: value.first)),
          ),
          if (settings.style == 'nothing') ...[
            const SizedBox(height: 24),
            const Text(
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'dark', label: Text('Black')),
                ButtonSegment(value: 'light', label: Text('White')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {settings.tone},
              onSelectionChanged: (value) =>
                  update(settings.copyWith(tone: value.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Grey dot texture'),
              subtitle: const Text('Subtle pattern behind the card'),
              value: settings.dots,
              onChanged: (v) => update(settings.copyWith(dots: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Red accents'),
              subtitle: const Text('Highlight the add button and overspending'),
              value: settings.redAccent,
              onChanged: (v) => update(settings.copyWith(redAccent: v)),
            ),
          ],
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide amounts'),
            subtitle: const Text(
              'Mask amounts and spending progress on the home screen',
            ),
            value: settings.hideAmounts,
            onChanged: (v) => update(settings.copyWith(hideAmounts: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show paise'),
            subtitle: const Text('Off rounds display amounts to the nearest rupee'),
            value: settings.decimals,
            onChanged: (v) => update(settings.copyWith(decimals: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spending progress'),
            subtitle: const Text('Show expenses as a share of income'),
            value: settings.progress,
            onChanged: (v) => update(settings.copyWith(progress: v)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Changes save automatically. Add the widget from your Android home screen’s widget picker.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

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
    final foreground = nothing && !dark
        ? const Color(0xFF141414)
        : Colors.white;
    final muted = nothing
        ? (dark ? const Color(0xFFE0E0E0) : const Color(0xFF333333))
        : foreground.withValues(alpha: .6);
    final accent = nothing && settings.redAccent
        ? const Color(0xFFCC2222)
        : foreground;
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
        ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: DotMatrixLabel(text: value, color: style?.color ?? foreground, fontSize: style?.fontSize ?? 14))
        : Text(value, style: style);
    Widget stat(String label, String amount) => Expanded(
      child: Container(
        padding: nothing ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: nothing ? null : BoxDecoration(
          color: foreground.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            matrixText(label, style: TextStyle(color: muted, fontSize: 10)),
            matrixText(
              settings.hideAmounts
                  ? '••••'
                  : '$amount${settings.decimals ? '.00' : ''}',
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
      return ClipRRect(borderRadius: BorderRadius.circular(28), child: Container(
        color: dark ? const Color(0xFF101010) : const Color(0xFFF5F5F5),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [DotMatrixLabel(color: foreground, fontSize: 11), const Spacer(),
              matrixText('OCT 2026', style: TextStyle(color: muted, fontSize: 10))]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              matrixText(settings.hideAmounts ? 'Monthly balance' : 'Overspent by', style: TextStyle(color: muted, fontSize: 10)),
              const SizedBox(height: 6),
              matrixText(value, style: TextStyle(color: accent, fontSize: 32)),
            ])),
              const SizedBox(width: 16), Container(width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: settings.redAccent ? accent : foreground),
                alignment: Alignment.center,
                child: matrixText('+', style: TextStyle(fontSize: 22, color: settings.redAccent ? Colors.white : dark ? Colors.black : Colors.white))),
            ]),
            const SizedBox(height: 18),
            Row(children: [stat('↓ Income', '₹20,000'), const SizedBox(width: 16), stat('↑ Spent', '₹30,000')]),
            const SizedBox(height: 14),
            if (settings.progress && !settings.hideAmounts) ...[
              DotMatrixProgress(value: 1, color: accent, trackColor: dark ? const Color(0xFF505050) : const Color(0xFFB8B8B8)),
              const SizedBox(height: 6),
            ],
            matrixText(settings.hideAmounts ? 'Amounts hidden' : settings.progress ? '150.0% of income spent' : 'Income minus expenses', style: TextStyle(color: muted, fontSize: 9)),
          ]),
        ),
      ));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: nothing
              ? (dark ? const Color(0xFF101010) : const Color(0xFFF5F5F5))
              : null,
          gradient: nothing ? null : LinearGradient(colors: colors),
        ),
        child: CustomPaint(
          painter: nothing && settings.dots
              ? _DotTexture(foreground.withValues(alpha: .12))
              : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (nothing)
                      DotMatrixLabel(color: foreground)
                    else
                      matrixText(
                        'My Expenses',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const Spacer(),
                    matrixText(
                      'OCT 2026',
                      style: TextStyle(color: muted, fontSize: 10),
                    ),
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
                            settings.hideAmounts
                                ? 'Monthly balance'
                                : 'Overspent by',
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
                        color: nothing
                            ? (settings.redAccent ? accent : foreground)
                            : Colors.white.withValues(alpha: .16),
                      ),
                      alignment: Alignment.center,
                      child: matrixText(
                        '+',
                        style: TextStyle(
                          color: nothing && !settings.redAccent
                              ? (dark ? Colors.black : Colors.white)
                              : Colors.white,
                          fontSize: 28,
                        ),
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
                  if (nothing) DotMatrixProgress(value: 1, color: accent, trackColor: dark ? const Color(0xFF505050) : const Color(0xFFB8B8B8)) else LinearProgressIndicator(
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
                      : settings.progress ? '150.0% of income spent' : 'Income minus expenses',
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







