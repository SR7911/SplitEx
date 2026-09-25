import 'package:flutter/material.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/screens/settlement/settlement_screen.dart';
import 'package:split_ex/services/balance_service.dart';

const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kBlue   = Color(0xFF3B82F6);
const _kPalette = [Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFF6366F1), Color(0xFF14B8A6), Color(0xFF8B5CF6), Color(0xFFEF4444)];

BoxDecoration _cardDeco(BuildContext context) {
  final cs     = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? cs.surfaceContainerHigh : cs.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

class PairSettlementTimeline extends StatefulWidget {
  final String memberA;
  final String memberB;
  final Map<String, Map<String, List<DebtTransaction>>> detailedMap;
  final Map<String, String> nameMap;
  final String userId;
  final String roomId;

  const PairSettlementTimeline({
    super.key,
    required this.memberA,
    required this.memberB,
    required this.detailedMap,
    required this.nameMap,
    required this.userId,
    required this.roomId,
  });

  @override
  State<PairSettlementTimeline> createState() => _PairSettlementTimelineState();
}

class _PairSettlementTimelineState extends State<PairSettlementTimeline> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final a = widget.memberA;
    final b = widget.memberB;
    final nameA = widget.nameMap[a] ?? a;
    final nameB = widget.nameMap[b] ?? b;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Transactions where B owes A (A paid)
    final aPaid = widget.detailedMap[b]?[a] ?? [];
    // Transactions where A owes B (B paid)
    final bPaid = widget.detailedMap[a]?[b] ?? [];

    final totalOwedToA = aPaid.fold(0.0, (s, t) => s + t.userShare);
    final totalOwedToB = bPaid.fold(0.0, (s, t) => s + t.userShare);
    final net = totalOwedToA - totalOwedToB; // positive: B owes A, negative: A owes B

    final bool currentUserIsDebtor = (net < 0 && widget.userId == a) || (net > 0 && widget.userId == b);
    final bool showSettleButton = net.abs() > 0.01 && currentUserIsDebtor;
    final bool currentUserIsCreditor = (net > 0 && widget.userId == a) || (net < 0 && widget.userId == b);
    final bool showViewButton = net.abs() > 0.01 && currentUserIsCreditor;    

    if (aPaid.isEmpty && bPaid.isEmpty) return const SizedBox.shrink();

    // Combine all transactions into a single timeline (ordered by date descending)
    final allTransactions = <_TimelineTransaction>[];
    for (final txn in aPaid) {
      allTransactions.add(_TimelineTransaction(
        transaction: txn,
        payerId: a,
        otherId: b,
        amountOwedByOther: txn.userShare,
      ));
    }
    for (final txn in bPaid) {
      allTransactions.add(_TimelineTransaction(
        transaction: txn,
        payerId: b,
        otherId: a,
        amountOwedByOther: txn.userShare,
      ));
    }
    allTransactions.sort((x, y) => y.transaction.date.compareTo(x.transaction.date));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _cardDeco(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar pair
                  SizedBox(
                    width: 52, height: 32,
                    child: Stack(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _kBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text(nameA.isNotEmpty ? nameA[0].toUpperCase() : '?', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue))),
                        ),
                        Positioned(
                          left: 20,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: _kAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                            ),
                            child: Center(child: Text(nameB.isNotEmpty ? nameB[0].toUpperCase() : '?', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kAmber))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$nameA ⇄ $nameB',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: net.abs() < 0.01
                          ? _kGreen.withValues(alpha: isDark ? 0.15 : 0.1)
                          : (net > 0
                              ? _kGreen.withValues(alpha: isDark ? 0.15 : 0.1)
                              : _kRed.withValues(alpha: isDark ? 0.15 : 0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      net.abs() < 0.01
                          ? 'Settled ✓'
                          : (net > 0
                              ? '$nameB owes ₹${net.toStringAsFixed(0)}'
                              : '$nameA owes ₹${(-net).toStringAsFixed(0)}'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: net.abs() < 0.01 ? _kGreen : (net > 0 ? _kGreen : _kRed),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allTransactions.length,
              itemBuilder: (context, index) => _TimelineTile(
                data: allTransactions[index],
                nameMap: widget.nameMap,
                userId: widget.userId,
                isLast: index == allTransactions.length - 1,
              ),
            ),
            // Net summary + action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Net balance', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                        const SizedBox(height: 2),
                        Text(
                          net.abs() < 0.01
                              ? 'All settled'
                              : (net > 0
                                  ? '$nameB owes $nameA ₹${net.toStringAsFixed(0)}'
                                  : '$nameA owes $nameB ₹${(-net).toStringAsFixed(0)}'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: net.abs() < 0.01 ? _kGreen : (net > 0 ? _kGreen : _kRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showSettleButton)
                    GestureDetector(
                      onTap: () {
                        final debt = net > 0
                            ? Debt(from: b, to: a, amount: net)
                            : Debt(from: a, to: b, amount: -net);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SettlementScreen(roomId: widget.roomId, debt: debt, nameMap: widget.nameMap),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payment_rounded, size: 16, color: _kGreen),
                            const SizedBox(width: 6),
                            const Text('Settle Up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen)),
                          ],
                        ),
                      ),
                    ),
                  if (showViewButton)
                    GestureDetector(
                      onTap: () {
                        final debt = net > 0
                            ? Debt(from: b, to: a, amount: net)
                            : Debt(from: a, to: b, amount: -net);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SettlementScreen(roomId: widget.roomId, debt: debt, nameMap: widget.nameMap),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _kBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_rounded, size: 16, color: _kBlue),
                            const SizedBox(width: 6),
                            const Text('View', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineTransaction {
  final DebtTransaction transaction;
  final String payerId;
  final String otherId;
  final double amountOwedByOther;

  _TimelineTransaction({
    required this.transaction,
    required this.payerId,
    required this.otherId,
    required this.amountOwedByOther,
  });
}

class _TimelineTile extends StatelessWidget {
  final _TimelineTransaction data;
  final Map<String, String> nameMap;
  final String userId;
  final bool isLast;

  const _TimelineTile({required this.data, required this.nameMap, required this.userId, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final txn = data.transaction;
    final payerId = data.payerId;
    final payerName = nameMap[payerId] ?? payerId;
    final otherId = data.otherId;
    final otherName = nameMap[otherId] ?? otherId;
    final isBill = txn.isBill == true;
    final isUserPayer = payerId == userId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final debtorId = otherId;
    final creditorId = payerId;
    final amountOwed = data.amountOwedByOther;

    final debtorDisplay = (debtorId == userId) ? 'You' : (nameMap[debtorId] ?? debtorId);
    final pillText = '$debtorDisplay owes ₹${amountOwed.toStringAsFixed(0)}';

    final Color pillColor;
    if (debtorId == userId) {
      pillColor = _kRed;
    } else if (creditorId == userId) {
      pillColor = _kGreen;
    } else {
      pillColor = _kAmber;
    }

    final iconColor = isBill ? _kBlue : (isUserPayer ? _kGreen : _kAmber);

    return InkWell(
      onTap: () => _showDetailDialog(context, txn, payerName, otherName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.07))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isBill ? Icons.receipt_long_rounded : Icons.payment_rounded,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₹${txn.totalAmount.toStringAsFixed(0)} • $payerName • ${_formatDate(txn.date)}',
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _splitText(txn),
                    style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.35)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pillColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                pillText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pillColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, DebtTransaction txn, String payerName, String otherName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              txn.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _detailRow('Amount', '₹${txn.totalAmount.toStringAsFixed(0)}'),
            _detailRow('Paid by', payerName),
            _detailRow('Date', _formatDate(txn.date)),
            _detailRow('Split type', _splitText(txn)),
            _detailRow('Split among', txn.splitAmong.length.toString()),
            _detailRow('Split members', txn.splitAmong.map((id) => nameMap[id] ?? id).join(', ')),
            const Divider(height: 24),
            _detailRow(
              data.payerId == userId ? '${otherName} owes' : 'You owe',
              '₹${data.amountOwedByOther.toStringAsFixed(0)}',
              highlight: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Builder(
        builder: (context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            Text(
              value,
              style: highlight
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  : const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _splitText(DebtTransaction txn) {
    switch (txn.splitType) {
      case SplitType.equal:
        return 'Split equally (${txn.splitAmong.length} ways)';
      case SplitType.dynamic:
        return 'Custom split';
      case SplitType.oneToOne:
        return 'One‑to‑one';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}