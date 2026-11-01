import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/app_transaction.dart';
import '../providers/providers.dart';
import '../widgets/flow_sense.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';

({double expenses, double income}) monthlyTransactionTotals(
  List<AppTransaction> transactions,
  DateTime month,
) {
  var expenses = 0.0;
  var income = 0.0;
  for (final transaction in transactions) {
    if (transaction.date.year != month.year ||
        transaction.date.month != month.month) {
      continue;
    }
    if (transaction.isExpense) {
      expenses += transaction.amount;
    } else {
      income += transaction.amount;
    }
  }
  return (expenses: expenses, income: income);
}

enum CalendarTransactionFilter { expenditure, income }

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? const Color(0xFFF0F7FF)
        : const Color(0xFF172033);
    final mutedColor = isDarkMode
        ? const Color(0xFF9EB0CC)
        : const Color(0xFF5C6A80);
    final transactions = ref.watch(transactionsProvider).value ?? const [];
    final budgets = ref.watch(weeklyBudgetsProvider).value ?? const [];
    final weekStart = DateTime.now();
    final startOfWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    ).subtract(Duration(days: weekStart.weekday - 1));
    final weekEnd = startOfWeek.add(const Duration(days: 7));
    final weeklyExpenses = transactions.where((transaction) {
      return transaction.isExpense &&
          !transaction.date.isBefore(startOfWeek) &&
          transaction.date.isBefore(weekEnd);
    }).toList();
    final dailySpend = List<double>.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      return weeklyExpenses
          .where((transaction) {
            final date = transaction.date;
            return date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    });
    final weeklyTotal = dailySpend.fold<double>(0, (sum, value) => sum + value);
    final money = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);

    return StandardPage(
      title: 'Insights',
      subtitle:
          'This week, ${DateFormat('d MMM').format(startOfWeek)} - '
          '${DateFormat('d MMM').format(weekEnd.subtract(const Duration(days: 1)))}',
      children: [
        MonthlySpendingCalendar(transactions: transactions),
        const SizedBox(height: 24),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WEEKLY SPEND',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                money.format(weeklyTotal),
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              WeeklySpendChart(values: dailySpend),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FlowSense(transactions: transactions, budgets: budgets),
      ],
    );
  }
}

class MonthlySpendingCalendar extends StatefulWidget {
  const MonthlySpendingCalendar({super.key, required this.transactions});

  final List<AppTransaction> transactions;

  @override
  State<MonthlySpendingCalendar> createState() =>
      _MonthlySpendingCalendarState();
}

class _MonthlySpendingCalendarState extends State<MonthlySpendingCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  CalendarTransactionFilter _filter = CalendarTransactionFilter.expenditure;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? const Color(0xFFF0F7FF)
        : const Color(0xFF172033);
    final mutedColor = isDarkMode
        ? const Color(0xFF9EB0CC)
        : const Color(0xFF5C6A80);
    final selectedDayColor = isDarkMode
        ? AppColor.mint
        : const Color(0xFF087F5B);
    final incomeColor = isDarkMode
        ? AppColor.mint
        : const Color(0xFF087F5B);
    final expenseColor = isDarkMode
        ? AppColor.coral
        : const Color(0xFFD94C45);
    final monthTotals = monthlyTransactionTotals(widget.transactions, _month);
    final firstDay = DateTime(_month.year, _month.month);
    final dayCount = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = firstDay.weekday - 1;
    final cellCount = ((offset + dayCount + 6) ~/ 7) * 7;
    final money = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final selectedTotals = _dayTotals(_selectedDate);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: Icon(Icons.chevron_left_rounded, color: AppColor.text),
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: Icon(Icons.chevron_right_rounded, color: AppColor.text),
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MonthTotal(
                  label: 'SPENDING',
                  amount: money.format(monthTotals.expenses),
                  color: expenseColor,
                ),
              ),
              Container(width: 1, height: 38, color: AppColor.border),
              Expanded(
                child: _MonthTotal(
                  label: 'INCOME',
                  amount: money.format(monthTotals.income),
                  color: incomeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<CalendarTransactionFilter>(
            segments: const [
              ButtonSegment(
                value: CalendarTransactionFilter.expenditure,
                label: Text('Expenditure'),
              ),
              ButtonSegment(
                value: CalendarTransactionFilter.income,
                label: Text('Income'),
              ),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                      return isDarkMode
                      ? AppColor.mint
                      : const Color(0xFF087F5B);
                }
                return textColor;
              }),
            ),
            onSelectionChanged: (selection) =>
                setState(() => _filter = selection.first),
          ),
          const SizedBox(height: 18),
          Row(
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: .9,
            ),
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > dayCount) return const SizedBox.shrink();
              final date = DateTime(_month.year, _month.month, day);
              final totals = _dayTotals(date);
              final hasActivity =
                  _filter == CalendarTransactionFilter.expenditure
                  ? totals.expenses > 0
                  : totals.income > 0;
              final selected = DateUtils.isSameDay(date, _selectedDate);
              final today = DateUtils.isSameDay(date, DateTime.now());

              return InkWell(
                onTap: () => setState(() => _selectedDate = date),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColor.mint.withValues(alpha: .18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: today
                        ? Border.all(color: AppColor.mint.withValues(alpha: .7))
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                        color: selected ? selectedDayColor : textColor,
                          fontSize: 12,
                          fontWeight: selected || today
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasActivity)
                            _ActivityDot(
                              color:
                                  _filter ==
                                      CalendarTransactionFilter.expenditure
                                  ? expenseColor
                                  : incomeColor,
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${_filter == CalendarTransactionFilter.expenditure ? 'Expenditure' : 'Income'} • ${DateFormat('EEEE, d MMM').format(_selectedDate)}',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            money.format(
              _filter == CalendarTransactionFilter.expenditure
                  ? selectedTotals.expenses
                  : selectedTotals.income,
            ),
            style: TextStyle(
              color: _filter == CalendarTransactionFilter.expenditure
                  ? expenseColor
              : incomeColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  ({double expenses, double income}) _dayTotals(DateTime date) {
    var expenses = 0.0;
    var income = 0.0;
    for (final transaction in widget.transactions) {
      if (!DateUtils.isSameDay(transaction.date, date)) continue;
      if (transaction.isExpense) {
        expenses += transaction.amount;
      } else {
        income += transaction.amount;
      }
    }
    return (expenses: expenses, income: income);
  }

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selectedDate = DateTime(_month.year, _month.month);
    });
  }
}

class _MonthTotal extends StatelessWidget {
  const _MonthTotal({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFF9EB0CC)
                  : const Color(0xFF5C6A80),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  const _ActivityDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class WeeklySpendChart extends StatelessWidget {
  const WeeklySpendChart({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return SizedBox(
      height: 142,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.asMap().entries.map((entry) {
          final value = entry.value;
          final height = maxValue == 0
              ? 4.0
              : (value / maxValue * 112).clamp(4.0, 112.0);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 22,
                  height: height,
                  decoration: BoxDecoration(
                    color: value == maxValue && value > 0
                        ? AppColor.mint
                        : AppColor.violet,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  labels[entry.key],
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9EB0CC)
                    : const Color(0xFF5C6A80),
                fontSize: 11,
              ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

