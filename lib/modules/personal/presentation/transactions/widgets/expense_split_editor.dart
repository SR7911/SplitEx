import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_ex/modules/personal/domain/entities/transactions/expense_split.dart';

class ExpenseSplitEditor extends StatefulWidget {
  final String totalText;
  final ExpenseSplit? initialSplit;
  final bool enabled;

  const ExpenseSplitEditor({
    super.key,
    required this.totalText,
    this.initialSplit,
    this.enabled = true,
  });

  @override
  State<ExpenseSplitEditor> createState() => ExpenseSplitEditorState();
}

class _PersonRow {
  final TextEditingController name;
  final TextEditingController amount;
  _PersonRow(String person, double? share)
    : name = TextEditingController(text: person),
      amount = TextEditingController(text: share?.toStringAsFixed(2) ?? '');

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class ExpenseSplitEditorState extends State<ExpenseSplitEditor> {
  late ExpenseSplitMode _mode;
  late final List<_PersonRow> _people;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialSplit?.mode ?? ExpenseSplitMode.equal;
    _people = [
      for (final share
          in widget.initialSplit?.shares ?? const <ExpenseSplitShare>[])
        _PersonRow(share.personName, share.amount),
    ];
    if (_people.isEmpty) _people.add(_PersonRow('', null));
  }

  @override
  void dispose() {
    for (final person in _people) person.dispose();
    super.dispose();
  }

  ExpenseSplit buildSplit() {
    final total = double.tryParse(widget.totalText.trim());
    if (total == null) throw StateError('Enter the expense total first.');
    final names = _people.map((person) => person.name.text.trim()).toList();
    if (names.any((name) => name.isEmpty)) {
      throw StateError('Enter every person’s name.');
    }
    final split = _mode == ExpenseSplitMode.equal
        ? equalExpenseSplit(total, names)
        : ExpenseSplit(
            mode: ExpenseSplitMode.manual,
            shares: [
              for (var i = 0; i < _people.length; i++)
                ExpenseSplitShare(
                  personName: names[i],
                  amount: _parseShare(_people[i].amount.text, names[i]),
                ),
            ],
          );
    split.validate(total);
    return split;
  }

  double _parseShare(String text, String name) {
    final value = double.tryParse(text.trim());
    if (value == null) throw StateError('Enter $name’s share.');
    moneyCents(value);
    return value;
  }

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label, {
    String? prefixText,
    String? errorText,
  }) => InputDecoration(
    labelText: label,
    prefixText: prefixText,
    errorText: errorText,
    filled: true,
    fillColor: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  );

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(widget.totalText.trim());
    final cs = Theme.of(context).colorScheme;
    int? ownCents;
    int? allocatedCents;
    String? problem;
    final overLimitRows = <int>{};
    try {
      if (total != null) {
        final totalCents = moneyCents(total);
        var allocated = 0;
        if (_mode == ExpenseSplitMode.equal) {
          final each = totalCents ~/ (_people.length + 1);
          allocated = each * _people.length;
        } else {
          for (var i = 0; i < _people.length; i++) {
            final person = _people[i];
            if (person.amount.text.trim().isEmpty) continue;
            allocated += moneyCents(double.parse(person.amount.text));
            if (allocated > totalCents) overLimitRows.add(i);
          }
        }
        allocatedCents = allocated;
        ownCents = totalCents - allocated;
        if (ownCents < 0) problem = 'People’s shares exceed the expense total.';
      }
    } catch (_) {
      problem = 'Enter valid amounts with at most two decimal places.';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Split this expense',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'You paid the full amount. Each person’s share will appear in Debts as money owed to you.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: .6),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<ExpenseSplitMode>(
          segments: const [
            ButtonSegment(value: ExpenseSplitMode.equal, label: Text('Equal')),
            ButtonSegment(
              value: ExpenseSplitMode.manual,
              label: Text('Manual'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: widget.enabled
              ? (value) => setState(() => _mode = value.first)
              : null,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _people.length; i++) ...[
          Row(
            key: ObjectKey(_people[i]),
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _people[i].name,
                  enabled: widget.enabled,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 14),
                  decoration: _fieldDecoration(context, 'Person ${i + 1}'),
                ),
              ),
              if (_mode == ExpenseSplitMode.manual) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _people[i].amount,
                    enabled: widget.enabled,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) =>
                            RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(newValue.text)
                            ? newValue
                            : oldValue,
                      ),
                    ],
                    style: const TextStyle(fontSize: 14),
                    decoration: _fieldDecoration(
                      context,
                      'Share',
                      prefixText: '₹ ',
                      errorText: overLimitRows.contains(i)
                          ? 'Over total'
                          : null,
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: widget.enabled && _people.length > 1
                    ? () => setState(() => _people.removeAt(i).dispose())
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove person',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled
                ? () => setState(() => _people.add(_PersonRow('', null)))
                : null,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add person'),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: problem == null
                ? cs.surfaceContainerHighest.withValues(alpha: .5)
                : cs.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expense total: ₹${total?.toStringAsFixed(2) ?? '0.00'}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              Text(
                'Others’ shares: ₹${((allocatedCents ?? 0) / 100).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
              Text(
                'Your share: ₹${((ownCents ?? 0) / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (problem != null)
                Text(
                  problem,
                  style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
