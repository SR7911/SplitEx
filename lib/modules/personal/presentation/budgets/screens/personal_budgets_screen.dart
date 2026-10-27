import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/modules/personal/dependencies.dart';
import 'package:split_ex/modules/personal/domain/entities/budgets/personal_budget.dart';
import 'package:split_ex/modules/personal/presentation/budgets/providers/personal_budget_providers.dart';
import 'package:split_ex/modules/personal/presentation/transactions/providers/personal_transaction_reads.dart';
import 'package:split_ex/modules/personal/presentation/transactions/screens/add_personal_transaction_screen.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';

/// Personal category budgets for one month.
class PersonalBudgetsScreen extends ConsumerWidget {
  final String monthKey;
  const PersonalBudgetsScreen({super.key, required this.monthKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(personalMonthBudgetsProvider(monthKey));
    final spending = ref.watch(personalDomainCategorySpendingProvider(monthKey));

    return Scaffold(
      appBar: const AppHeader(showBack: true, title: 'Manage Budgets', showNotification: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: GradientBody(
        child: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return const Center(child: Text('No budgets set.\nTap + to add category budgets.', textAlign: TextAlign.center));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            itemBuilder: (context, i) {
              final b = budgets[i];
              final spent = spending[b.category] ?? 0;
              final ratio = b.budget > 0 ? spent / b.budget : 0.0;
              final percent = (ratio * 100).toInt();
              final color = percent <= 70 ? Colors.green : percent <= 100 ? Colors.orange : Colors.red;

              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(b.category, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: ratio.clamp(0, 1.5), color: color, minHeight: 6),
                      ),
                      const SizedBox(height: 4),
                      Text('₹${spent.toStringAsFixed(0)} / ₹${b.budget.toStringAsFixed(0)} ($percent%)', style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      final userId = ref.read(personalUserIdProvider).valueOrNull;
                      if (userId != null) {
                        await ref.read(personalBudgetRepositoryProvider).delete(userId, b.id);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context, WidgetRef ref) {
    final spending = ref.read(personalDomainCategorySpendingProvider(monthKey));
    // Merge hardcoded categories with any categories user has spent on
    final allCategories = <String>{...personalCategories, ...spending.keys}.toList()..sort();

    String category = allCategories.first;
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: allCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Budget Amount', prefixText: '₹ ', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || !amount.isFinite || amount <= 0) return;
                final userId = ref.read(personalUserIdProvider).valueOrNull;
                if (userId == null) return;

                final budget = PersonalBudget(id: '', category: category, budget: amount, userId: userId, month: monthKey);
                await ref.read(savePersonalBudgetProvider)(userId, budget);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
