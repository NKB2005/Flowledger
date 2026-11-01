import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/app_transaction.dart';
import '../models/categories.dart';
import '../providers/providers.dart';
import '../widgets/app_text.dart';
import '../widgets/glass_ui.dart';
import '../widgets/standard_page.dart';
import 'add_transaction_screen.dart';

enum TransactionFilter { all, expenses, income }

enum GroupByMode { date, month, year }

enum SortOrder { newestFirst, oldestFirst }

/// Backward compatible helper used by tests
Map<DateTime, List<AppTransaction>> groupTransactionsByDay(
  List<AppTransaction> transactions,
) {
  final grouped = <DateTime, List<AppTransaction>>{};
  for (final transaction in transactions) {
    final date = DateUtils.dateOnly(transaction.date);
    grouped.putIfAbsent(date, () => []).add(transaction);
  }
  final dates = grouped.keys.toList()
    ..sort((first, second) => second.compareTo(first));
  return {for (final date in dates) date: grouped[date]!};
}

class TransactionGroup {
  final String key;
  final String title;
  final DateTime representativeDate;
  final List<AppTransaction> transactions;

  TransactionGroup({
    required this.key,
    required this.title,
    required this.representativeDate,
    required this.transactions,
  });

  double get totalExpense => transactions
      .where((t) => t.isExpense)
      .fold<double>(0, (sum, t) => sum + t.amount);

  double get totalIncome => transactions
      .where((t) => !t.isExpense)
      .fold<double>(0, (sum, t) => sum + t.amount);
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.onAdd});

  final VoidCallback? onAdd;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionFilter _filter = TransactionFilter.all;
  GroupByMode _groupBy = GroupByMode.date;
  SortOrder _sortOrder = SortOrder.newestFirst;
  int? _selectedYear;
  int? _selectedMonth;
  String? _expandedKey;
  bool _hasInitializedExpansion = false;

  static final _dayFormatter = DateFormat('EEEE, d MMMM y');
  static final _monthYearFormatter = DateFormat('MMMM y');
  static final _shortDateFormatter = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return LiquidBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: transactions.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColor.mint),
              ),
              error: (error, _) => Center(
                child: GlassCard(
                  child: Text(
                    'Could not load transactions: $error',
                    style: TextStyle(color: AppColor.text),
                  ),
                ),
              ),
              data: (list) {
                // Collect available years and months from actual transaction data
                final availableYears = list.map((t) => t.date.year).toSet().toList()
                  ..sort((a, b) => b.compareTo(a));

                final availableMonths = (list.where(
                  (t) => _selectedYear == null || t.date.year == _selectedYear,
                )).map((t) => t.date.month).toSet().toList()
                  ..sort();

                // Reset selected month if no longer available in filtered year
                if (_selectedMonth != null && !availableMonths.contains(_selectedMonth)) {
                  _selectedMonth = null;
                }

                // Filter transactions based on type, year, and month
                final filtered = list.where((transaction) {
                  final matchesType = switch (_filter) {
                    TransactionFilter.all => true,
                    TransactionFilter.expenses => transaction.isExpense,
                    TransactionFilter.income => !transaction.isExpense,
                  };
                  if (!matchesType) return false;
                  if (_selectedYear != null && transaction.date.year != _selectedYear) {
                    return false;
                  }
                  if (_selectedMonth != null && transaction.date.month != _selectedMonth) {
                    return false;
                  }
                  return true;
                }).toList();

                // Group and sort transactions
                final groups = _buildGroups(filtered);

                if (!_hasInitializedExpansion) {
                  _expandedKey = groups.isEmpty ? null : groups.first.key;
                  _hasInitializedExpansion = true;
                }
                if (_expandedKey != null && !groups.any((g) => g.key == _expandedKey)) {
                  _expandedKey = groups.isEmpty ? null : groups.first.key;
                }

                final headerWidgets = <Widget>[
                  // Segmented Button: All / Expense / Income
                  SegmentedButton<TransactionFilter>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionFilter.all,
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: TransactionFilter.expenses,
                        label: Text('Expense'),
                      ),
                      ButtonSegment(
                        value: TransactionFilter.income,
                        label: Text('Income'),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() {
                        _filter = selection.first;
                        _hasInitializedExpansion = false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Sort & Grouping Controls
                  _buildSortAndFilterCard(availableYears, availableMonths),
                  const SizedBox(height: 16),
                ];

                final totalItems = headerWidgets.length +
                    (list.isEmpty || groups.isEmpty ? 1 : groups.length);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 115, 20, 170),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    if (index < headerWidgets.length) {
                      return headerWidgets[index];
                    }

                    if (list.isEmpty) {
                      return GlassCard(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              color: AppColor.mint,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            heading('No transactions yet'),
                            const SizedBox(height: 6),
                            secondary('Tap + to add your first one.'),
                          ],
                        ),
                      );
                    }

                    if (groups.isEmpty) {
                      return GlassCard(
                        child: Column(
                          children: [
                            Icon(
                              Icons.filter_list_off_rounded,
                              color: AppColor.muted,
                              size: 28,
                            ),
                            const SizedBox(height: 10),
                            secondary(
                              _selectedMonth != null || _selectedYear != null
                                  ? 'No transactions found for the selected filter.'
                                  : _filter == TransactionFilter.income
                                      ? 'No income transactions found.'
                                      : 'No expense transactions found.',
                            ),
                            if (_selectedMonth != null ||
                                _selectedYear != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedYear = null;
                                    _selectedMonth = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Reset date filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColor.mint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    final groupIndex = index - headerWidgets.length;
                    final group = groups[groupIndex];
                    final isExpanded = _expandedKey == group.key;

                    return Padding(
                      key: ValueKey(group.key),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        blurSigma: 0,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(
                                () => _expandedKey = isExpanded ? null : group.key,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    if (_groupBy == GroupByMode.month) ...[
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            AppColor.mint.withValues(alpha: 0.16),
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          size: 17,
                                          color: AppColor.mint,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ] else if (_groupBy == GroupByMode.year) ...[
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColor.violet
                                            .withValues(alpha: 0.16),
                                        child: Icon(
                                          Icons.event_note_rounded,
                                          size: 17,
                                          color: AppColor.violet,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.title,
                                            style: TextStyle(
                                              color: AppColor.text,
                                              fontWeight: FontWeight.w800,
                                              fontSize:
                                                  _groupBy == GroupByMode.year
                                                      ? 16
                                                      : 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${group.transactions.length} ${group.transactions.length == 1 ? 'transaction' : 'transactions'}',
                                            style: TextStyle(
                                              color: AppColor.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '- ${money.format(group.totalExpense)}',
                                          style: TextStyle(
                                            color: AppColor.coral,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '+ ${money.format(group.totalIncome)}',
                                          style: TextStyle(
                                            color: AppColor.mint,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      color: AppColor.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              firstChild: const SizedBox(
                                width: double.infinity,
                              ),
                              secondChild: Column(
                                children: [
                                  Divider(
                                    height: 1,
                                    color: AppColor.border,
                                  ),
                                  ...group.transactions.map(
                                    (transaction) => _transactionTile(
                                      transaction,
                                      money,
                                      showDateInSubtitle:
                                          _groupBy != GroupByMode.date,
                                    ),
                                  ),
                                ],
                              ),
                              crossFadeState: isExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 260),
                              firstCurve: Curves.easeInOutCubic,
                              secondCurve: Curves.easeInOutCubic,
                              sizeCurve: Curves.easeOutCubic,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AppHeader(
                title: 'Activity',
                subtitle: 'Your recent activity',
                showDateBadge: false,
                trailing: IconButton(
                  onPressed: widget.onAdd ??
                      () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddTransactionScreen(),
                            ),
                          ),
                  icon: Icon(
                    Icons.add_rounded,
                    color: AppColor.mint,
                    size: 26,
                  ),
                  tooltip: 'Add transaction',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndFilterCard(List<int> availableYears, List<int> availableMonths) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter = _selectedYear != null || _selectedMonth != null;

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Sort by (Date / Month / Year) and Order Toggle (Newest / Oldest)
          Row(
            children: [
              Icon(Icons.swap_vert_rounded, size: 17, color: AppColor.mint),
              const SizedBox(width: 5),
              Text(
                'Sort:',
                style: TextStyle(
                  color: AppColor.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              _buildPillChip('Date', GroupByMode.date, isDark),
              const SizedBox(width: 5),
              _buildPillChip('Month', GroupByMode.month, isDark),
              const SizedBox(width: 5),
              _buildPillChip('Year', GroupByMode.year, isDark),
              const Spacer(),
              // Order Toggle Button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _sortOrder = _sortOrder == SortOrder.newestFirst
                        ? SortOrder.oldestFirst
                        : SortOrder.newestFirst;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColor.mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColor.mint.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortOrder == SortOrder.newestFirst
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: AppColor.mint,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _sortOrder == SortOrder.newestFirst ? 'Newest' : 'Oldest',
                        style: TextStyle(
                          color: AppColor.mint,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Row 2: Year & Month Filter Row
          if (availableYears.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColor.border),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 14, color: AppColor.muted),
                  const SizedBox(width: 5),
                  Text(
                    'Year:',
                    style: TextStyle(
                      color: AppColor.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  _buildFilterChip(
                    label: 'All',
                    isSelected: _selectedYear == null,
                    onTap: () => setState(() => _selectedYear = null),
                  ),
                  for (final year in availableYears) ...[
                    const SizedBox(width: 4),
                    _buildFilterChip(
                      label: '$year',
                      isSelected: _selectedYear == year,
                      onTap: () => setState(() => _selectedYear = year),
                    ),
                  ],
                  if (_groupBy != GroupByMode.year && availableMonths.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(height: 12, width: 1, color: AppColor.border),
                    const SizedBox(width: 8),
                    Text(
                      'Month:',
                      style: TextStyle(
                        color: AppColor.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _buildFilterChip(
                      label: 'All',
                      isSelected: _selectedMonth == null,
                      onTap: () => setState(() => _selectedMonth = null),
                    ),
                    for (final m in availableMonths) ...[
                      const SizedBox(width: 4),
                      _buildFilterChip(
                        label: _monthAbbr(m),
                        isSelected: _selectedMonth == m,
                        onTap: () => setState(() => _selectedMonth = m),
                      ),
                    ],
                  ],
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedYear = null;
                          _selectedMonth = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColor.coral.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 12, color: AppColor.coral),
                            const SizedBox(width: 2),
                            Text(
                              'Clear',
                              style: TextStyle(
                                color: AppColor.coral,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillChip(String label, GroupByMode mode, bool isDark) {
    final isSelected = _groupBy == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _groupBy = mode;
          _hasInitializedExpansion = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColor.mint
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColor.text,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColor.mint.withValues(alpha: 0.22)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColor.mint.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColor.mint : AppColor.muted,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<TransactionGroup> _buildGroups(List<AppTransaction> items) {
    final Map<String, List<AppTransaction>> map = {};
    final Map<String, DateTime> dateMap = {};
    final Map<String, String> titleMap = {};

    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    for (final t in items) {
      String key;
      String title;
      DateTime repDate;

      switch (_groupBy) {
        case GroupByMode.date:
          final d = DateUtils.dateOnly(t.date);
          key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          repDate = d;
          if (DateUtils.isSameDay(d, today)) {
            title = 'Today';
          } else if (DateUtils.isSameDay(d, yesterday)) {
            title = 'Yesterday';
          } else {
            title = _dayFormatter.format(d);
          }
          break;

        case GroupByMode.month:
          key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
          repDate = DateTime(t.date.year, t.date.month, 1);
          title = _monthYearFormatter.format(repDate);
          break;

        case GroupByMode.year:
          key = '${t.date.year}';
          repDate = DateTime(t.date.year, 1, 1);
          title = 'Year ${t.date.year}';
          break;
      }

      map.putIfAbsent(key, () => []).add(t);
      dateMap[key] = repDate;
      titleMap[key] = title;
    }

    final groups = map.entries.map((entry) {
      final list = entry.value;
      // Sort transactions inside each group according to sortOrder
      list.sort((a, b) {
        return _sortOrder == SortOrder.newestFirst
            ? b.date.compareTo(a.date)
            : a.date.compareTo(b.date);
      });

      return TransactionGroup(
        key: entry.key,
        title: titleMap[entry.key]!,
        representativeDate: dateMap[entry.key]!,
        transactions: list,
      );
    }).toList();

    // Sort the groups themselves according to sortOrder
    groups.sort((a, b) {
      return _sortOrder == SortOrder.newestFirst
          ? b.representativeDate.compareTo(a.representativeDate)
          : a.representativeDate.compareTo(b.representativeDate);
    });

    return groups;
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '$month';
  }

  Widget _transactionTile(
    AppTransaction transaction,
    NumberFormat money, {
    bool showDateInSubtitle = false,
  }) {
    final category = categoryFor(transaction.category);
    final subtitleText = showDateInSubtitle
        ? '${_shortDateFormatter.format(transaction.date)} · ${transaction.category}'
        : transaction.category;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColor.coral.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final repo = ref.read(transactionRepositoryProvider);
        final itemLabel = transaction.note.trim().isNotEmpty
            ? transaction.note.trim()
            : transaction.category;
        final typeLabel = transaction.isExpense ? 'Expense' : 'Income';

        repo?.delete(transaction.id);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColor.border,
                width: 1,
              ),
            ),
            content: Text(
              '$typeLabel "$itemLabel" deleted',
              style: TextStyle(
                color: AppColor.text,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: AppColor.mint,
              onPressed: () {
                repo?.restore(transaction);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: category.color.withAlpha(46),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(
          transaction.note.isEmpty ? transaction.category : transaction.note,
          style: TextStyle(color: AppColor.text, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(color: AppColor.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${transaction.isExpense ? '-' : '+'}${money.format(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: transaction.isExpense ? AppColor.coral : AppColor.mint,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: AppColor.muted,
              tooltip: 'Edit transaction',
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(existing: transaction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
