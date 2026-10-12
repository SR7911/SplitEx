import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:split_ex/models/loan_model.dart';
import 'package:split_ex/providers/auth_provider.dart';
import 'package:split_ex/providers/loan_provider.dart';
import 'package:split_ex/services/loan_service.dart';

void showAddLoanSheet(BuildContext context, {LoanModel? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddLoanSheet(existing: existing),
  );
}

class _AddLoanSheet extends ConsumerStatefulWidget {
  final LoanModel? existing;
  const _AddLoanSheet({this.existing});

  @override
  ConsumerState<_AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<_AddLoanSheet> {
  final _titleCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _processingFeeCtrl = TextEditingController();
  final _insuranceFeeCtrl = TextEditingController();
  final _otherChargesCtrl = TextEditingController();
  final _customEmiCtrl = TextEditingController();

  LoanType _loanType = LoanType.borrowed;
  DateTime _startDate = DateTime.now();
  DateTime? _emiStartDate; // null = auto (startDate + 1 month)
  int _emiDueDay = 1;
  bool _loading = false;
  bool _showCharges = false;
  bool _applyGst = false;
  bool _overrideEmi = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _principalCtrl.text = e.principal.toStringAsFixed(0);
      _rateCtrl.text = e.annualInterestRate.toString();
      _tenureCtrl.text = e.tenureMonths.toString();
      _nameCtrl.text = e.lenderBorrowerName ?? '';
      _notesCtrl.text = e.notes ?? '';
      _loanType = e.loanType;
      _startDate = e.startDate;
      _emiStartDate = e.emiStartDate;
      _emiDueDay = e.emiDueDay;
      if (e.customEmi != null && e.customEmi! > 0) {
        _overrideEmi = true;
        _customEmiCtrl.text = e.customEmi!.toStringAsFixed(0);
      }
      if (e.processingFee > 0) _processingFeeCtrl.text = e.processingFee.toStringAsFixed(0);
      if (e.insuranceFee > 0) _insuranceFeeCtrl.text = e.insuranceFee.toStringAsFixed(0);
      if (e.otherCharges > 0) _otherChargesCtrl.text = e.otherCharges.toStringAsFixed(0);
      if (e.totalCharges > 0) _showCharges = true;
      _applyGst = e.gstOnFees > 0;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _principalCtrl, _rateCtrl, _tenureCtrl,
      _nameCtrl, _notesCtrl, _processingFeeCtrl, _insuranceFeeCtrl, _otherChargesCtrl, _customEmiCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _processingFee => double.tryParse(_processingFeeCtrl.text) ?? 0;
  double get _insuranceFee => double.tryParse(_insuranceFeeCtrl.text) ?? 0;
  double get _otherCharges => double.tryParse(_otherChargesCtrl.text) ?? 0;
  double get _gstAmount => _applyGst ? (_processingFee * 0.18) : 0;
  double get _totalCharges => _processingFee + _insuranceFee + _otherCharges + _gstAmount;
  double get _netDisbursed {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    return (p - _totalCharges).clamp(0, double.infinity);
  }

  double get _previewEmi {
    if (_overrideEmi) return double.tryParse(_customEmiCtrl.text) ?? 0;
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final r = double.tryParse(_rateCtrl.text) ?? 0;
    final n = int.tryParse(_tenureCtrl.text) ?? 0;
    if (p <= 0 || n <= 0) return 0;
    return LoanModel(
      id: '', userId: '', title: '', loanType: _loanType,
      principal: p, annualInterestRate: r, tenureMonths: n,
      startDate: _startDate, emiDueDay: _emiDueDay,
      status: LoanStatus.active, createdAt: DateTime.now(),
    ).baseEmi;
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.45)) : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emi = _previewEmi;
    final tenure = int.tryParse(_tenureCtrl.text) ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle + Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.account_balance_rounded, color: cs.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isEdit ? 'Edit Loan' : 'Add Loan / EMI',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Scrollable body ──────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Loan type toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: LoanType.values.map((t) {
                          final selected = _loanType == t;
                          final isBorrowed = t == LoanType.borrowed;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _loanType = t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  color: selected ? cs.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: selected
                                      ? [BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isBorrowed ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      size: 15,
                                      color: selected ? Colors.white : cs.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isBorrowed ? 'I Borrowed' : 'I Lent',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.white : cs.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Section: Basic Info ──────────────────────────────
                    _SectionLabel(label: 'Basic Info'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: _dec('Loan Title', hint: 'e.g. HDFC Home Loan', icon: Icons.label_outline),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _dec(
                        _loanType == LoanType.borrowed ? 'Lender Name' : 'Borrower Name',
                        hint: 'Bank / Person name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Section: Loan Details ────────────────────────────
                    _SectionLabel(label: 'Loan Details'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _principalCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: _dec('Principal (₹)', hint: '500000', icon: Icons.currency_rupee),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: _dec('Annual Rate (%)', hint: '8.5 or 0', icon: Icons.percent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tenureCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: _dec('Tenure (months)', hint: '24', icon: Icons.timelapse_rounded),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _DayDropdown(value: _emiDueDay, dec: _dec, onChanged: (v) => setState(() => _emiDueDay = v))),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Start date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          helpText: 'Select Loan Start Date',
                        );
                        if (picked != null) setState(() {
                          _startDate = picked;
                          _emiStartDate = null; // reset so auto recalculates
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: cs.onSurface.withOpacity(0.45)),
                            const SizedBox(width: 12),
                            Text(
                              'Loan Start: ${DateFormat('dd MMM yyyy').format(_startDate)}',
                              style: TextStyle(fontSize: 14, color: cs.onSurface),
                            ),
                            const Spacer(),
                            Icon(Icons.edit_calendar_outlined, size: 16, color: cs.onSurface.withOpacity(0.35)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // First EMI date
                    InkWell(
                      onTap: () async {
                        final defaultEmi = DateTime(_startDate.year, _startDate.month + 1, _emiDueDay);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _emiStartDate ?? defaultEmi,
                          firstDate: _startDate,
                          lastDate: DateTime(2100),
                          helpText: 'Select First EMI Date',
                        );
                        if (picked != null) setState(() => _emiStartDate = picked);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: _emiStartDate != null
                              ? Border.all(color: cs.primary.withOpacity(0.4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event_repeat_rounded, size: 18,
                                color: _emiStartDate != null ? cs.primary : cs.onSurface.withOpacity(0.45)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _emiStartDate != null
                                        ? 'First EMI: ${DateFormat('dd MMM yyyy').format(_emiStartDate!)}'
                                        : 'First EMI: ${DateFormat('dd MMM yyyy').format(DateTime(_startDate.year, _startDate.month + 1, _emiDueDay))} (auto)',
                                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                                  ),
                                  if (_emiStartDate == null)
                                    Text('Tap to override', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
                                ],
                              ),
                            ),
                            if (_emiStartDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _emiStartDate = null),
                                child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface.withOpacity(0.4)),
                              )
                            else
                              Icon(Icons.edit_calendar_outlined, size: 16, color: cs.onSurface.withOpacity(0.35)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── EMI Override ─────────────────────────────────────
                    _SectionLabel(label: 'EMI Amount'),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => setState(() {
                        _overrideEmi = !_overrideEmi;
                        if (!_overrideEmi) _customEmiCtrl.clear();
                      }),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18,
                                color: _overrideEmi ? cs.primary : cs.onSurface.withOpacity(0.45)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Override EMI amount',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                                  Text('Use actual EMI instead of calculated',
                                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _overrideEmi,
                              onChanged: (v) => setState(() {
                                _overrideEmi = v;
                                if (!v) _customEmiCtrl.clear();
                              }),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_overrideEmi) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customEmiCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: _dec('Custom EMI Amount (₹)', hint: 'Enter actual EMI', icon: Icons.currency_rupee),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── EMI Preview ──────────────────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(sizeFactor: anim, child: child),
                      ),
                      child: emi > 0
                          ? Padding(
                              key: const ValueKey('emi'),
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cs.primary.withOpacity(0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.calculate_rounded, size: 16, color: cs.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Monthly EMI', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
                                        Text(
                                          '₹${emi.toStringAsFixed(0)}',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Total payable', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6))),
                                        Text(
                                          '₹${(emi * tenure).toStringAsFixed(0)}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-emi')),
                    ),

                    // ── Section: Charges & Fees ──────────────────────────
                    InkWell(
                      onTap: () => setState(() => _showCharges = !_showCharges),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 18, color: cs.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 10),
                            Text(
                              'Charges & Fees',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                            ),
                            if (_totalCharges > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '−₹${_totalCharges.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              _showCharges ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: cs.onSurface.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, child: child),
                      child: _showCharges
                          ? Padding(
                              key: const ValueKey('charges'),
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _processingFeeCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          decoration: _dec('Processing Fee (₹)', hint: '0', icon: Icons.percent_rounded),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _insuranceFeeCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (_) => setState(() {}),
                                          decoration: _dec('Insurance Fee (₹)', hint: '0', icon: Icons.shield_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _otherChargesCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setState(() {}),
                                    decoration: _dec('Other Charges (₹)', hint: 'Stamp duty, legal, etc.', icon: Icons.more_horiz_rounded),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: Checkbox(
                                          value: _applyGst,
                                          onChanged: (v) => setState(() => _applyGst = v ?? false),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Apply 18% GST on processing fee',
                                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                                      ),
                                      if (_applyGst && _processingFee > 0) ...[
                                        const Spacer(),
                                        Text(
                                          '= ₹${_gstAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (_totalCharges > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Text('Deductions: ', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                                          Text('₹${_totalCharges.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange)),
                                          const Spacer(),
                                          Text('Net disbursed: ', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                                          Text('₹${_netDisbursed.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-charges')),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _dec('Notes (optional)', hint: 'Any remarks...', icon: Icons.notes_rounded),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isEdit ? 'Update Loan' : 'Add Loan',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMissedEmiDialog(
    BuildContext context,
    String userId,
    String loanId,
    List<DateTime> missed,
    LoanService service,
  ) async {
    final fmt = DateFormat('dd MMM yyyy');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
          SizedBox(width: 8),
          Text('Past EMIs Detected'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${missed.length} EMI${missed.length > 1 ? 's' : ''} appear unpaid since the start date:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            ...missed.take(5).map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.circle, size: 6, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text(fmt.format(d), style: const TextStyle(fontSize: 12)),
              ]),
            )),
            if (missed.length > 5)
              Text('  ...and ${missed.length - 5} more', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            const Text(
              'Mark all as paid (backdated)?',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Paid'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await service.logMissedEmis(userId, loanId, missed);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${missed.length} past EMI${missed.length > 1 ? 's' : ''} logged')),
                );
              }
            },
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final principal = double.tryParse(_principalCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    final tenure = int.tryParse(_tenureCtrl.text);
    if (_titleCtrl.text.trim().isEmpty || principal == null || principal <= 0 || rate == null || tenure == null || tenure <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = ref.read(authStateProvider).valueOrNull?.uid;
      if (userId == null) return;
      final service = ref.read(loanServiceProvider);

      if (_isEdit) {
        await service.updateLoan(
          userId, widget.existing!.id,
          principal: principal,
          annualInterestRate: rate,
          tenureMonths: tenure,
          emiDueDay: _emiDueDay,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          customEmi: _overrideEmi ? (double.tryParse(_customEmiCtrl.text) ?? 0) : 0,
          processingFee: _processingFee,
          insuranceFee: _insuranceFee,
          otherCharges: _otherCharges,
          gstOnFees: _gstAmount,
        );
      } else {
        final customEmiVal = _overrideEmi ? double.tryParse(_customEmiCtrl.text) : null;
        final newLoan = LoanModel(
          id: '',
          userId: userId,
          title: _titleCtrl.text.trim(),
          loanType: _loanType,
          principal: principal,
          annualInterestRate: rate,
          tenureMonths: tenure,
          startDate: _startDate,
          emiDueDay: _emiDueDay,
          status: LoanStatus.active,
          lenderBorrowerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
          customEmi: (customEmiVal != null && customEmiVal > 0) ? customEmiVal : null,
          processingFee: _processingFee,
          insuranceFee: _insuranceFee,
          otherCharges: _otherCharges,
          gstOnFees: _gstAmount,
          emiStartDate: _emiStartDate,
        );
        final loanId = await service.addLoan(userId, newLoan);

        // Check for missed EMIs immediately after adding
        final loanForCheck = LoanModel(
          id: loanId, userId: userId,
          title: newLoan.title, loanType: newLoan.loanType,
          principal: principal, annualInterestRate: rate,
          tenureMonths: tenure, startDate: _startDate,
          emiDueDay: _emiDueDay, status: LoanStatus.active,
          createdAt: DateTime.now(),
          emiStartDate: _emiStartDate,
        );
        final missed = service.getMissedEmiDates(loanForCheck, []);

        if (missed.isNotEmpty && mounted) {
          await _showMissedEmiDialog(context, userId, loanId, missed, service);
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── EMI due day dropdown ──────────────────────────────────────────────────

class _DayDropdown extends StatelessWidget {
  final int value;
  final InputDecoration Function(String, {String? hint, IconData? icon}) dec;
  final ValueChanged<int> onChanged;
  const _DayDropdown({required this.value, required this.dec, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: dec('EMI Due Day', icon: Icons.event_repeat_rounded),
      items: List.generate(28, (i) => i + 1)
          .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
          .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}
