import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:split_ex/modules/room/domain/entities/bill_model.dart';
import 'package:split_ex/modules/room/domain/entities/expense_model.dart';
import 'package:split_ex/modules/room/domain/entities/debt_transaction.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/modules/room/domain/repositories/room_receipt_exporter.dart';
import 'package:split_ex/shared/domain/entities/settlement_model.dart';

class ReceiptGenerator implements RoomReceiptExporter {
  @override
  Future<String> generateMonthlyReceiptPath({
    required String roomName,
    required String month,
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required Map<String, String> nameMap,
    required List<Debt> debts,
    required int memberCount,
    Map<String, Map<String, List<DebtTransaction>>>? detailedDebtsMap,
    List<String>? memberIds,
    List<SettlementModel> settlements = const [],
  }) async {
    final file = await generateMonthlyReceipt(
      roomName: roomName,
      month: month,
      expenses: expenses,
      bills: bills,
      nameMap: nameMap,
      debts: debts,
      memberCount: memberCount,
      detailedDebtsMap: detailedDebtsMap,
      memberIds: memberIds,
      settlements: settlements,
    );
    return file.path;
  }

  @override
  Future<void> sharePdfPath(String path, {String? text}) =>
      sharePdf(File(path), text: text);

  /// Generates a monthly receipt PDF and returns the file.
  Future<File> generateMonthlyReceipt({
    required String roomName,
    required String month,
    required List<ExpenseModel> expenses,
    required List<BillModel> bills,
    required Map<String, String> nameMap,
    required List<Debt> debts,
    required int memberCount,
    Map<String, Map<String, List<DebtTransaction>>>? detailedDebtsMap,
    List<String>? memberIds,
    List<SettlementModel> settlements = const [],
  }) async {
    final pdf = pw.Document();
    final monthLabel = _formatMonth(month);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final totalBills = bills.fold<double>(0, (s, b) => s + b.amount);
    final grandTotal = totalExpenses + totalBills;
    final perPerson = memberCount > 0 ? grandTotal / memberCount : 0.0;

    final pairWidgets =
        (detailedDebtsMap != null && memberIds != null && memberIds.length > 1)
        ? _buildPairDetails(detailedDebtsMap, memberIds, nameMap, settlements)
        : <pw.Widget>[];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text(
              'SplitEx - Monthly Receipt',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              '$roomName \u2022 $monthLabel',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 12),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                _summaryRow(
                  'Total Expenses',
                  'Rs. ${totalExpenses.toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Total Bills',
                  'Rs. ${totalBills.toStringAsFixed(2)}',
                ),
                pw.Divider(),
                _summaryRow(
                  'Grand Total',
                  'Rs. ${grandTotal.toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Average per participant ($memberCount people; actual shares vary)',
                  'Rs. ${perPerson.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          if (settlements.isNotEmpty) ...[
            pw.Text(
              'Payment History',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['From', 'To', 'Amount', 'Status', 'Payment date'],
              data: settlements
                  .map(
                    (s) => [
                      nameMap[s.fromUserId] ?? s.fromUserId,
                      nameMap[s.toUserId] ?? s.toUserId,
                      'Rs. ${s.amount.toStringAsFixed(2)}',
                      s.status.name,
                      DateFormat('dd MMM yyyy').format(s.createdAt),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 20),
          ],

          // Bills section
          if (bills.isNotEmpty) ...[
            pw.Text(
              'Bills',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['Type', 'Amount', 'Paid By', 'Date'],
              data: bills
                  .map(
                    (b) => [
                      b.typeName,
                      'Rs. ${b.amount.toStringAsFixed(2)}',
                      nameMap[b.paidBy] ?? b.paidBy,
                      DateFormat('dd MMM').format(b.date),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Expenses section
          if (expenses.isNotEmpty) ...[
            pw.Text(
              'Expenses',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['Title', 'Category', 'Amount', 'Paid By', 'Date'],
              data: expenses
                  .map(
                    (e) => [
                      e.title,
                      e.category,
                      'Rs. ${e.amount.toStringAsFixed(2)}',
                      nameMap[e.paidBy] ?? e.paidBy,
                      DateFormat('dd MMM').format(e.date),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Settlement section
          if (debts.isNotEmpty) ...[
            pw.Text(
              'Settlements Due',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(6),
              headers: ['From', 'To', 'Amount'],
              data: debts
                  .map(
                    (d) => [
                      nameMap[d.from] ?? d.from,
                      nameMap[d.to] ?? d.to,
                      'Rs. ${d.amount.toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Pair-wise spending details
          ...pairWidgets,

          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              'Generated by SplitEx on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();

    // Sanitize room name: replace characters that are invalid in file names
    // Invalid on Android: / \ : * ? " < > | , space
    final safeRoomName = roomName
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_')
        .replaceAll(',', '_')
        .replaceAll(' ', '_'); // optional, but safer

    final fileName = 'SplitEx_${safeRoomName}_$month.pdf';
    final file = File('${dir.path}/$fileName');

    // Ensure directory exists (though getTemporaryDirectory should give existing dir)
    await file.create(recursive: true);

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  List<pw.Widget> _buildPairDetails(
    Map<String, Map<String, List<DebtTransaction>>> detailedMap,
    List<String> memberIds,
    Map<String, String> nameMap,
    List<SettlementModel> settlements,
  ) {
    final widgets = <pw.Widget>[];
    widgets.add(
      pw.Text(
        'Pair-wise Spending Details',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
    widgets.add(pw.SizedBox(height: 6));

    for (int i = 0; i < memberIds.length; i++) {
      for (int j = i + 1; j < memberIds.length; j++) {
        final a = memberIds[i];
        final b = memberIds[j];
        final nameA = nameMap[a] ?? a;
        final nameB = nameMap[b] ?? b;

        // B owes A (A paid)
        final aPaid = detailedMap[b]?[a] ?? [];
        // A owes B (B paid)
        final bPaid = detailedMap[a]?[b] ?? [];

        if (aPaid.isEmpty && bPaid.isEmpty) continue;

        final totalOwedToA = aPaid.fold(0.0, (s, t) => s + t.userShare);
        final totalOwedToB = bPaid.fold(0.0, (s, t) => s + t.userShare);
        var net = totalOwedToA - totalOwedToB;
        for (final payment in settlements) {
          if (payment.status != SettlementStatus.confirmed) continue;
          if (payment.fromUserId == b && payment.toUserId == a)
            net -= payment.amount;
          if (payment.fromUserId == a && payment.toUserId == b)
            net += payment.amount;
        }

        final netLabel = net.abs() < 0.01
            ? 'Settled'
            : (net > 0
                  ? '$nameB owes $nameA Rs. ${net.toStringAsFixed(2)}'
                  : '$nameA owes $nameB Rs. ${(-net).toStringAsFixed(2)}');

        // Combine all transactions
        final allTxns = <List<String>>[];
        for (final txn in aPaid) {
          allTxns.add([
            txn.title,
            nameA,
            'Rs. ${txn.totalAmount.toStringAsFixed(2)}',
            'Rs. ${txn.userShare.toStringAsFixed(2)}',
            DateFormat('dd MMM').format(txn.date),
          ]);
        }
        for (final txn in bPaid) {
          allTxns.add([
            txn.title,
            nameB,
            'Rs. ${txn.totalAmount.toStringAsFixed(2)}',
            'Rs. ${txn.userShare.toStringAsFixed(2)}',
            DateFormat('dd MMM').format(txn.date),
          ]);
        }

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '$nameA  \u2194  $nameB',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(netLabel, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellPadding: const pw.EdgeInsets.all(4),
                  headers: ['Title', 'Paid By', 'Total', 'Share Owed', 'Date'],
                  data: allTxns,
                ),
              ],
            ),
          ),
        );
      }
    }

    if (widgets.length <= 2) {
      return []; // No pairs with transactions
    }
    return widgets;
  }

  pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat('MMMM yyyy').format(dt);
  }

  /// Share PDF via WhatsApp or other apps.
  Future<void> sharePdf(File file, {String? text}) async {
    await Share.shareXFiles([
      XFile(file.path),
    ], text: text ?? 'Monthly room expense receipt from SplitEx');
  }
}
