import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/screens/personal/add_personal_transaction_screen.dart';
import 'package:split_ex/screens/personal/personal_expense_tab.dart' show incomeExpensePills, budgetUsageCard, quickActionsRow;

// ============================================================
// STYLE 1 — Seamless Bleed
// ============================================================

class SeamlessBleedLayout extends StatelessWidget {
  final dynamic summary;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev, onNext;
  final String monthKey, userName;
  final List<Widget> bodySliver;
  const SeamlessBleedLayout({
    super.key,
    required this.summary,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.monthKey,
    required this.userName,
    required this.bodySliver,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final income = summary.income as double;
    final expenses = summary.expenses as double;
    final remaining = summary.remaining as double;
    final isPositive = remaining >= 0;
    final spendRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final savingsRate = income > 0 ? ((remaining / income) * 100).clamp(-999.0, 100.0) : 0.0;
    const onCard = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.65);
    final heroColor = !isPositive
        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626))
        : spendRatio > 0.8
            ? (isDark ? const Color(0xFF78350F) : const Color(0xFFD97706))
            : cs.primary;

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: 320, child: ColoredBox(color: heroColor)),
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: heroColor,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_greeting()}, $userName 👋',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onCard)),
                  const SizedBox(height: 2),
                  Text('Financial overview', style: TextStyle(fontSize: 12, color: onCardMuted)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BleedNavChip(onTap: onPrev, icon: Icons.chevron_left),
                      Text(DateFormat('MMMM yyyy').format(selectedMonth),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCard)),
                      _BleedNavChip(onTap: isCurrentMonth ? null : onNext, icon: Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(isPositive ? 'Remaining Balance' : 'Overspent By',
                      style: TextStyle(fontSize: 12, color: onCardMuted)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: remaining.abs()),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Text('₹${v.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _BleedChip(icon: Icons.south_rounded, label: 'Income', value: '₹${income.toStringAsFixed(0)}'),
                      const SizedBox(width: 10),
                      _BleedChip(icon: Icons.north_rounded, label: 'Spent', value: '₹${expenses.toStringAsFixed(0)}'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isPositive ? Icons.savings_rounded : Icons.warning_amber_rounded, size: 16, color: onCard),
                          const SizedBox(height: 2),
                          Text(income > 0 ? '${savingsRate.toInt()}%' : '—',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: onCard)),
                          Text('saved', style: TextStyle(fontSize: 9, color: onCardMuted)),
                        ]),
                      ),
                    ],
                  ),
                  if (income > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: spendRatio, minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation(
                          spendRatio > 0.8
                              ? const Color(0xFFFCA5A5)
                              : spendRatio > 0.5
                                  ? const Color(0xFFFDE68A)
                                  : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
            ClipPath(
              clipper: _WaveClipper(),
              child: Container(height: 36, color: heroColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(children: [
                incomeExpensePills(context, summary),
                const SizedBox(height: 16),
                budgetUsageCard(context, summary),
                const SizedBox(height: 20),
                quickActionsRow(context, monthKey),
                const SizedBox(height: 20),
                ...bodySliver,
              ]),
            ),
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: () => showAddPersonalTransactionSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _BleedNavChip extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  const _BleedNavChip({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.3)),
      ),
    );
  }
}

class _BleedChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _BleedChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.65)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.65), fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ]),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, 0)
      ..lineTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.5)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}

// ============================================================
// STYLE 2 — Frosted Glass
// ============================================================

class FrostedGlassLayout extends StatelessWidget {
  final dynamic summary;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev, onNext;
  final String monthKey, userName;
  final List<Widget> bodySliver;
  const FrostedGlassLayout({
    super.key,
    required this.summary,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.monthKey,
    required this.userName,
    required this.bodySliver,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final income = summary.income as double;
    final expenses = summary.expenses as double;
    final remaining = summary.remaining as double;
    final isPositive = remaining >= 0;
    final spendRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final usage = summary.budgetUsage as double;
    final percent = (usage * 100).clamp(0, 999).toInt();
    final saved = (income - expenses).clamp(0.0, double.infinity);
    final spentRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    final savedRatio = income > 0 ? (saved / income).clamp(0.0, 1.0) : 0.0;
    final statusLabel = percent <= 70 ? 'On Track' : percent <= 100 ? 'Caution' : 'Over Budget';
    const onCard = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.65);
    final heroColor = !isPositive
        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626))
        : spendRatio > 0.8
            ? (isDark ? const Color(0xFF78350F) : const Color(0xFFD97706))
            : cs.primary;
    final frosted = BoxDecoration(
      color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    );

    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: 560, child: ColoredBox(color: heroColor)),
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: heroColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_greeting()}, $userName 👋',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onCard)),
                const SizedBox(height: 2),
                Text('Here\'s your financial overview', style: TextStyle(fontSize: 12, color: onCardMuted)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BleedNavChip(onTap: onPrev, icon: Icons.chevron_left),
                    Text(DateFormat('MMMM yyyy').format(selectedMonth),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCard)),
                    _BleedNavChip(onTap: isCurrentMonth ? null : onNext, icon: Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 16),
                // Frosted hero card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: frosted,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isPositive ? 'Remaining Balance' : 'Overspent By',
                        style: TextStyle(fontSize: 11, color: onCardMuted)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: remaining.abs()),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text('₹${v.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1.5)),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      _BleedChip(icon: Icons.south_rounded, label: 'Income', value: '₹${income.toStringAsFixed(0)}'),
                      const SizedBox(width: 10),
                      _BleedChip(icon: Icons.north_rounded, label: 'Spent', value: '₹${expenses.toStringAsFixed(0)}'),
                    ]),
                    if (income > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: spendRatio, minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(
                            spendRatio > 0.8
                                ? const Color(0xFFFCA5A5)
                                : spendRatio > 0.5
                                    ? const Color(0xFFFDE68A)
                                    : Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                // Frosted stat pills
                Row(children: [
                  Expanded(child: _FrostedPill(label: 'Income', value: income, icon: Icons.south_rounded, frosted: frosted)),
                  const SizedBox(width: 10),
                  Expanded(child: _FrostedPill(label: 'Expenses', value: expenses, icon: Icons.north_rounded, frosted: frosted)),
                  const SizedBox(width: 10),
                  Expanded(child: _FrostedPill(
                    label: income - expenses >= 0 ? 'Saved' : 'Deficit',
                    value: (income - expenses).abs(),
                    icon: income - expenses >= 0 ? Icons.savings_rounded : Icons.trending_down_rounded,
                    frosted: frosted,
                  )),
                ]),
                const SizedBox(height: 12),
                // Frosted budget card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: frosted,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('Budget Overview',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onCard)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(statusLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: onCard)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 8,
                        child: Row(children: [
                          if (spentRatio > 0)
                            Flexible(flex: (spentRatio * 1000).toInt(), child: Container(color: Colors.redAccent.withValues(alpha: 0.85))),
                          if (savedRatio > 0)
                            Flexible(flex: (savedRatio * 1000).toInt(), child: Container(color: Colors.greenAccent.withValues(alpha: 0.85))),
                          if (spentRatio + savedRatio < 1.0)
                            Flexible(
                              flex: ((1.0 - spentRatio - savedRatio) * 1000).toInt().clamp(1, 1000),
                              child: Container(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _FrostedDot(color: Colors.redAccent, label: 'Spent', value: '${(spentRatio * 100).toInt()}%'),
                      const SizedBox(width: 14),
                      _FrostedDot(color: Colors.greenAccent, label: 'Saved', value: '${(savedRatio * 100).toInt()}%'),
                      const Spacer(),
                      Text(income > 0 ? '$percent% used' : 'No income',
                          style: TextStyle(fontSize: 10, color: onCardMuted)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(children: [
                quickActionsRow(context, monthKey),
                const SizedBox(height: 20),
                ...bodySliver,
              ]),
            ),
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: () => showAddPersonalTransactionSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _FrostedPill extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final BoxDecoration frosted;
  const _FrostedPill({required this.label, required this.value, required this.icon, required this.frosted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: frosted,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(height: 6),
        Text('₹${value.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.65))),
      ]),
    );
  }
}

class _FrostedDot extends StatelessWidget {
  final Color color;
  final String label, value;
  const _FrostedDot({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
      const SizedBox(width: 3),
      Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    ]);
  }
}

// ============================================================
// STYLE 3 — Sliver Compact
// ============================================================

class SliverCompactLayout extends StatelessWidget {
  final dynamic summary;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrev, onNext;
  final String monthKey, userName;
  final List<Widget> bodySliver;
  const SliverCompactLayout({
    super.key,
    required this.summary,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrev,
    required this.onNext,
    required this.monthKey,
    required this.userName,
    required this.bodySliver,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final income = summary.income as double;
    final expenses = summary.expenses as double;
    final remaining = summary.remaining as double;
    final isPositive = remaining >= 0;
    final spendRatio = income > 0 ? (expenses / income).clamp(0.0, 1.0) : 0.0;
    const onCard = Colors.white;
    final onCardMuted = Colors.white.withValues(alpha: 0.65);
    final heroColor = !isPositive
        ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626))
        : spendRatio > 0.8
            ? (isDark ? const Color(0xFF78350F) : const Color(0xFFD97706))
            : cs.primary;
    final barColor = spendRatio > 0.8
        ? const Color(0xFFFCA5A5)
        : spendRatio > 0.5
            ? const Color(0xFFFDE68A)
            : Colors.white.withValues(alpha: 0.85);

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              expandedHeight: 210,
              collapsedHeight: 110,
              pinned: true,
              backgroundColor: heroColor,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  color: heroColor,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${_greeting()}, $userName 👋',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onCard)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _BleedNavChip(onTap: onPrev, icon: Icons.chevron_left),
                          Text(DateFormat('MMMM yyyy').format(selectedMonth),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: onCard)),
                          _BleedNavChip(onTap: isCurrentMonth ? null : onNext, icon: Icons.chevron_right),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(isPositive ? 'Remaining' : 'Overspent', style: TextStyle(fontSize: 11, color: onCardMuted)),
                          Text('₹${remaining.abs().toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -1)),
                        ]),
                        const Spacer(),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _CompactTag(label: '↓ ₹${income.toStringAsFixed(0)}', color: const Color(0xFF22C55E)),
                          const SizedBox(height: 4),
                          _CompactTag(label: '↑ ₹${expenses.toStringAsFixed(0)}', color: const Color(0xFFEF4444)),
                        ]),
                      ]),
                    ],
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('₹${remaining.abs().toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onCard, letterSpacing: -0.5)),
                        const SizedBox(width: 6),
                        Text(isPositive ? 'left' : 'over', style: TextStyle(fontSize: 11, color: onCardMuted)),
                        const Spacer(),
                        _CompactTag(label: '↓ ₹${income.toStringAsFixed(0)}', color: const Color(0xFF22C55E)),
                        const SizedBox(width: 6),
                        _CompactTag(label: '↑ ₹${expenses.toStringAsFixed(0)}', color: const Color(0xFFEF4444)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: spendRatio, minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(barColor),
                        ),
                      ),
                    ],
                  ),
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: income > 0
                    ? LinearProgressIndicator(
                        value: spendRatio, minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(barColor),
                      )
                    : const SizedBox(height: 6),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  incomeExpensePills(context, summary),
                  const SizedBox(height: 16),
                  budgetUsageCard(context, summary),
                  const SizedBox(height: 20),
                  quickActionsRow(context, monthKey),
                  const SizedBox(height: 20),
                  ...bodySliver,
                ]),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: () => showAddPersonalTransactionSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _CompactTag extends StatelessWidget {
  final String label;
  final Color color;
  const _CompactTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}
