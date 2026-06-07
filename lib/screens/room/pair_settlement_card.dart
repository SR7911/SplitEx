import 'package:flutter/material.dart';
import 'package:split_ex/models/expense_model.dart';
import 'package:split_ex/providers/dashboard_provider.dart';
import 'package:split_ex/screens/settlement/settlement_screen.dart';
import 'package:split_ex/services/balance_service.dart';

// screens/room/pair_settlement_timeline.dart

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: pair names + net summary
          
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$nameA ⇄ $nameB',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: net > 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      net.abs() < 0.01
                          ? 'Settled'
                          : (net > 0 ? '$nameB owes ₹${net.toStringAsFixed(0)}' : '$nameA owes ₹${(-net).toStringAsFixed(0)}'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: net > 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            // Timeline list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allTransactions.length,
              itemBuilder: (context, index) => _TimelineTile(
                data: allTransactions[index],
                nameMap: widget.nameMap,
                userId: widget.userId,
              ),
            ),
            const Divider(height: 24),
            // Net summary and settle button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          net.abs() < 0.01
                              ? 'All settled'
                              : (net > 0
                                  ? '$nameB owes $nameA ₹${net.toStringAsFixed(0)}'
                                  : '$nameA owes $nameB ₹${(-net).toStringAsFixed(0)}'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: net > 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showSettleButton)
                    ElevatedButton.icon(
                      onPressed: () {
                        final debt = net > 0
                            ? Debt(from: b, to: a, amount: net)  // B owes A
                            : Debt(from: a, to: b, amount: -net); // A owes B
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettlementScreen(
                              roomId: widget.roomId,
                              debt: debt,
                              nameMap: widget.nameMap,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Settle Up'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  if (showViewButton)
                    OutlinedButton.icon(
                      onPressed: () {
                        // Same debt but creditor views it
                        final debt = net > 0
                            ? Debt(from: b, to: a, amount: net)
                            : Debt(from: a, to: b, amount: -net);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettlementScreen(
                              roomId: widget.roomId,
                              debt: debt,
                              nameMap: widget.nameMap,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Settlement'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

  const _TimelineTile({required this.data, required this.nameMap, required this.userId});

  @override
  Widget build(BuildContext context) {
    final txn = data.transaction;
    final payerId = data.payerId;
    final payerName = nameMap[payerId] ?? payerId;
    final otherId = data.otherId;
    final otherName = nameMap[otherId] ?? otherId;
    final isBill = txn.isBill == true;
    final isUserPayer = payerId == userId;

    final debtorId = otherId;
    final creditorId = payerId;
    final amountOwed = data.amountOwedByOther;

    final debtorDisplay = (debtorId == userId) ? 'You' : (nameMap[debtorId] ?? debtorId);
    final pillText = '$debtorDisplay owes ${amountOwed.toStringAsFixed(0)}';

    // Pill colors
    Color pillBg;
    Color pillTextColor;
    if (debtorId == userId) {
      pillBg = Colors.red.shade100;
      pillTextColor = Colors.red.shade800;
    } else if (creditorId == userId) {
      pillBg = Colors.green.shade100;
      pillTextColor = Colors.green.shade800;
    } else {
      pillBg = Colors.grey.shade200;
      pillTextColor = Colors.grey.shade800;
    }

    // Amount color based on whether user is involved
    final amountColor = (debtorId == userId || creditorId == userId)
        ? (debtorId == userId ? Colors.red.shade700 : Colors.green.shade700)
        : Colors.black87;

    final tileColor = isBill ? Colors.blue.shade50 : null;

    return InkWell(
      onTap: () => _showDetailDialog(context, txn, payerName, otherName),
      child: Container(
        decoration: BoxDecoration(
          color: tileColor,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUserPayer ? Colors.green.shade50 : Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBill ? Icons.receipt_long : Icons.payment,
                size: 20,
                color: isUserPayer ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 12),
            // Details column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Amount line: highlighted with color
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '₹${txn.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: amountColor,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: ' • $payerName • ${_formatDate(txn.date)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Split type as plain text (no background)
                  Text(
                    _splitText(txn),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pillText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: pillTextColor,
                ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: highlight
                ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                : const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
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