import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/expense_store.dart';
import '../core/app_colors.dart';
import '../core/auth_service.dart';
import '../core/profile_image_store.dart';
import '../models/categories.dart';
import '../providers/providers.dart';
import '../widgets/app_text.dart';
import '../widgets/flow_sense.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/weekly_budget_section.dart';

String dashboardGreeting([DateTime? now, String name = 'Alex']) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return 'Good morning, $name';
  if (hour < 18) return 'Good afternoon, $name';
  return 'Good evening, $name';
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, required this.store, this.onSeeAll});
  final ExpenseStore store;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: AppColor.revision,
      builder: (context, _) {
        final user = AuthService().currentUser;
        final name = displayNameForUser(user);
        final transactions = ref.watch(transactionsProvider).value ?? const [];
        final budgets = ref.watch(weeklyBudgetsProvider).value ?? const [];
        final initialBalance = ref.watch(initialBalanceProvider).value;
        final income = transactions
            .where((transaction) => !transaction.isExpense)
            .fold<double>(0, (sum, transaction) => sum + transaction.amount);
        final expenses = transactions
            .where((transaction) => transaction.isExpense)
            .fold<double>(0, (sum, transaction) => sum + transaction.amount);
        final balance = initialBalance == null
            ? null
            : initialBalance + income - expenses;

        return LiquidBackground(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                floating: false,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                forceMaterialTransparency: true,
                automaticallyImplyLeading: false,
                toolbarHeight: 68,
                titleSpacing: 0,
                title: AppHeader(
                  title: 'FlowLedger',
                  subtitle: dashboardGreeting(null, name),
                  showDateBadge: true,
                  trailing: Semantics(
                    button: true,
                    label: 'Open profile',
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                      child: ValueListenableBuilder<String?>(
                        valueListenable: ProfileImageStore.path,
                        builder: (context, imagePath, child) {
                          ImageProvider? avatarImage;
                          if (imagePath != null && imagePath.isNotEmpty) {
                            avatarImage = FileImage(File(imagePath));
                          } else if (user?.photoURL != null &&
                              user!.photoURL!.isNotEmpty) {
                            avatarImage = NetworkImage(user.photoURL!);
                          }

                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColor.mint,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(
                                    initialsForUser(user),
                                    style: const TextStyle(
                                      color: Color(0xFF0D1F17),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                BalanceCard(
                  initialBalance: initialBalance,
                  balance: balance,
                  income: income,
                  expenses: expenses,
                  onSetInitialBalance: () => _setInitialBalance(context, ref),
                ),
                if (store.latestNote.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LATEST NOTE',
                          style: TextStyle(
                            color: AppColor.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          store.latestNote,
                          style: TextStyle(
                            color: AppColor.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          store.latestCategory,
                          style: TextStyle(color: AppColor.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                heading('Your money, in motion'),
                const SizedBox(height: 7),
                FlowSense(transactions: transactions, budgets: budgets),
                const SizedBox(height: 16),
                WeeklyBudgetSection(
                  transactions: transactions,
                  budgets: budgets,
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    heading('Recent activity'),
                    TextButton(
                      onPressed: onSeeAll,
                      child: const Text('See all'),
                    ),
                  ],
                ),
                if (transactions.isEmpty)
                  GlassCard(
                    child: secondary(
                      'Your recent transactions will appear here.',
                    ),
                  )
                else
                  ...transactions.take(3).map((transaction) {
                    final category = categoryFor(transaction.category);
                    final date = DateFormat(
                      'd MMM, y',
                    ).format(transaction.date);
                    final amount = NumberFormat.currency(
                      symbol: 'Rs. ',
                      decimalDigits: 2,
                    ).format(transaction.amount);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransactionTile(
                        category.icon,
                        transaction.note.isEmpty
                            ? transaction.category
                            : transaction.note,
                        '${transaction.category} • $date',
                        '${transaction.isExpense ? '-' : '+'}$amount',
                        transaction.isExpense ? AppColor.coral : AppColor.mint,
                      ),
                    );
                  }),
              ]),
            ),
          ),
        ],
      ),
    );
  },
);
}

  Future<void> _setInitialBalance(BuildContext context, WidgetRef ref) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => const _SetBalanceDialog(),
    );
    if (amount == null) return;
    final repo = ref.read(transactionRepositoryProvider);
    if (repo == null) return;
    try {
      await repo.setInitialBalance(amount);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set balance: $error')),
        );
      }
    }
  }
}

class _SetBalanceDialog extends StatefulWidget {
  const _SetBalanceDialog();

  @override
  State<_SetBalanceDialog> createState() => _SetBalanceDialogState();
}

class _SetBalanceDialogState extends State<_SetBalanceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set total balance'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(
        prefixText: 'Rs. ',
        hintText: '0.00',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const Text('Set balance'),
      ),
    ],
  );
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.initialBalance,
    required this.balance,
    required this.income,
    required this.expenses,
    required this.onSetInitialBalance,
  });

  final double? initialBalance;
  final double? balance;
  final double income;
  final double expenses;
  final VoidCallback onSetInitialBalance;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final totalCashflow = income + expenses;
    final incomeRatio = totalCashflow > 0 ? (income / totalCashflow) : 0.5;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: AppColor.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              if (initialBalance != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColor.mint.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColor.mint.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: AppColor.mint),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: AppColor.mint,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          heading(
            balance == null
                ? 'Balance not set'
                : currency.format(balance),
            balance == null ? 24 : 31,
          ),
          const SizedBox(height: 18),

          // Monthly Cashflow Split Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColor.isDarkMode
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColor.border,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Income Metric
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColor.mint.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              size: 14,
                              color: AppColor.mint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Income',
                                  style: TextStyle(
                                    color: AppColor.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currency.format(income),
                                    style: TextStyle(
                                      color: AppColor.mint,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Expenses Metric
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Spent',
                                  style: TextStyle(
                                    color: AppColor.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    currency.format(expenses),
                                    style: TextStyle(
                                      color: AppColor.coral,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColor.coral.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 14,
                              color: AppColor.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Visual Split Proportion Line
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: totalCashflow == 0
                        ? Container(
                            color: AppColor.isDarkMode
                                ? Colors.white12
                                : Colors.black12,
                          )
                        : Row(
                            children: [
                              Flexible(
                                flex: (incomeRatio * 100).round().clamp(1, 99),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColor.mint,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                flex: ((1 - incomeRatio) * 100).round().clamp(1, 99),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColor.coral,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          if (initialBalance == null) ...[
            const SizedBox(height: 16),
            secondary('Set it once to track your live balance.'),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onSetInitialBalance,
              icon: const Icon(Icons.lock_outline_rounded, size: 18),
              label: const Text('Set starting balance'),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColor.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Income increases your balance; expenses reduce it.',
                    style: TextStyle(
                      color: AppColor.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
