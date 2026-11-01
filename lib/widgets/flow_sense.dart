import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/app_transaction.dart';
import '../models/weekly_budget.dart';
import 'glass_ui.dart';

String flowSenseSuggestion({
  required List<AppTransaction> transactions,
  List<WeeklyBudget> budgets = const [],
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final weekStart = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final weeklyExpenses = transactions.where((transaction) {
    return transaction.isExpense &&
        !transaction.date.isBefore(weekStart) &&
        transaction.date.isBefore(weekEnd);
  }).toList();
  final money = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0);

  if (weeklyExpenses.isEmpty) {
    return 'Log this week’s expenses to get a saving suggestion based on your spending.';
  }

  final budgetAdvice =
      budgets
          .where((budget) => budget.limit > 0)
          .map((budget) {
            final spent = weeklyExpenses
                .where(
                  (transaction) =>
                      _canonicalCategory(transaction.category) ==
                      _canonicalCategory(budget.category),
                )
                .fold<double>(
                  0,
                  (sum, transaction) => sum + transaction.amount,
                );
            return (budget: budget, spent: spent);
          })
          .where((entry) => entry.spent / entry.budget.limit >= .8)
          .toList()
        ..sort(
          (first, second) => (second.spent / second.budget.limit).compareTo(
            first.spent / first.budget.limit,
          ),
        );

  if (budgetAdvice.isNotEmpty) {
    final advice = budgetAdvice.first;
    final overBy = advice.spent - advice.budget.limit;
    if (overBy > 0) {
      return '${advice.budget.category} is ${money.format(overBy)} over its weekly limit. Pause non-essential ${advice.budget.category.toLowerCase()} spending for the rest of the week.';
    }
    return '${advice.budget.category} has ${money.format(advice.budget.limit - advice.spent)} left in its weekly budget. Keep optional purchases below that to stay on track.';
  }

  final spendByCategory = <String, double>{};
  for (final transaction in weeklyExpenses) {
    spendByCategory.update(
      transaction.category,
      (spent) => spent + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }
  final topCategory = spendByCategory.entries.reduce(
    (first, second) => first.value >= second.value ? first : second,
  );
  return '${topCategory.key} is your biggest spend this week at ${money.format(topCategory.value)}. Cutting it by 10% could free up about ${money.format(topCategory.value * .1)}.';
}

String _canonicalCategory(String category) {
  final normalized = category.trim().toLowerCase();
  return normalized == 'travel' ? 'transport' : normalized;
}

class FlowSense extends StatelessWidget {
  const FlowSense({
    super.key,
    required this.transactions,
    this.budgets = const [],
  });

  final List<AppTransaction> transactions;
  final List<WeeklyBudget> budgets;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? const Color(0xFFF0F7FF)
        : const Color(0xFF172033);
    final accentColor = isDarkMode
        ? AppColor.mint
        : const Color(0xFF087F5B);
    return GlassCard(
      child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: accentColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FLOW SENSE',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                flowSenseSuggestion(
                  transactions: transactions,
                  budgets: budgets,
                ),
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }
}
