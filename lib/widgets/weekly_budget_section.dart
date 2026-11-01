import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/app_transaction.dart';
import '../models/categories.dart';
import '../models/weekly_budget.dart';
import '../providers/providers.dart';
import 'app_text.dart';
import 'glass_ui.dart';

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _canonicalCategory(String category) {
  final normalized = category.trim().toLowerCase();
  return normalized == 'travel' ? 'transport' : normalized;
}

bool budgetCategoryMatches(String transactionCategory, String budgetCategory) =>
    _canonicalCategory(transactionCategory) ==
    _canonicalCategory(budgetCategory);

class WeeklyBudgetSection extends ConsumerWidget {
  const WeeklyBudgetSection({
    super.key,
    required this.transactions,
    required this.budgets,
  });

  final List<AppTransaction> transactions;
  final List<WeeklyBudget> budgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = _startOfWeek(DateTime.now());
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weeklyExpenses = transactions.where((transaction) {
      return transaction.isExpense &&
          !transaction.date.isBefore(weekStart) &&
          transaction.date.isBefore(weekEnd);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            heading('Weekly budgets', 17),
            IconButton(
              onPressed: () => _addBudget(context, ref),
              icon: Icon(Icons.add_rounded, color: AppColor.mint),
              tooltip: 'Add weekly budget',
            ),
          ],
        ),
        if (budgets.isEmpty)
          GlassCard(
            child: Row(
              children: [
                Icon(Icons.track_changes_rounded, color: AppColor.mint),
                const SizedBox(width: 12),
                Expanded(child: secondary('Set a weekly limit to stay on track.')),
              ],
            ),
          )
        else
          ...budgets.map((budget) {
            final spent = weeklyExpenses
                .where(
                  (transaction) => budgetCategoryMatches(
                    transaction.category,
                    budget.category,
                  ),
                )
                .fold<double>(
                  0,
                  (sum, transaction) => sum + transaction.amount,
                );
            final progress = budget.limit <= 0
                ? 0.0
                : (spent / budget.limit).clamp(0.0, 1.0);
            final color = progress >= .8 ? AppColor.coral : AppColor.violet;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BudgetTile(
                budget.category,
                progress,
                color,
                spent: spent,
                limit: budget.limit,
                onDelete: () => _deleteBudget(context, ref, budget),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _deleteBudget(
    BuildContext context,
    WidgetRef ref,
    WeeklyBudget budget,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete weekly budget?'),
        content: Text(
          'Remove the weekly limit for ${budget.category}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.coral,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) return;

    try {
      await repo.deleteWeeklyBudget(budget.category, id: budget.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
            backgroundColor: AppColor.card,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColor.border,
                width: 1,
              ),
            ),
            content: Text(
              '${budget.category} budget deleted',
              style: TextStyle(
                color: AppColor.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColor.mint,
              onPressed: () {
                repo.setWeeklyBudget(
                  category: budget.category,
                  limit: budget.limit,
                );
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete budget: $error')),
        );
      }
    }
  }

  Future<void> _addBudget(BuildContext context, WidgetRef ref) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => const _AddBudgetDialog(),
    );
    if (values == null) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.setWeeklyBudget(
        category: values['category'] as String,
        limit: values['limit'] as double,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save budget: $error')),
        );
      }
    }
  }
}

class _AddBudgetDialog extends StatefulWidget {
  const _AddBudgetDialog();

  @override
  State<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<_AddBudgetDialog> {
  late final TextEditingController _limitController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController();
    _selectedCategory = expenseCategories.first.name;
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    final limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) return;
    Navigator.of(context).pop({
      'category': _selectedCategory,
      'limit': limit,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set weekly budget'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: expenseCategories
              .map(
                (category) => DropdownMenuItem(
                  value: category.name,
                  child: Text(category.name),
                ),
              )
              .toList(),
          onChanged: (category) {
            if (category != null) {
              setState(() => _selectedCategory = category);
            }
          },
        ),
        TextField(
          controller: _limitController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Weekly limit',
            prefixText: 'Rs. ',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Save'),
      ),
    ],
  );
}

class BudgetTile extends StatelessWidget {
  const BudgetTile(
    this.name,
    this.value,
    this.color, {
    super.key,
    required this.spent,
    required this.limit,
    this.onDelete,
  });

  final String name;
  final double value;
  final Color color;
  final double spent;
  final double limit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);
    final usage = limit <= 0 ? 0.0 : spent / limit;
    final usageLabel = usage > 1
        ? '${money.format(spent - limit)} over limit'
        : '${(usage * 100).round()}% used';
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppColor.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${money.format(spent)} of ${money.format(limit)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usageLabel,
                  style: TextStyle(color: AppColor.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: color,
              backgroundColor: const Color(0x22FFFFFF),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColor.coral.withValues(alpha: 0.85),
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Delete $name budget',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}