import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/auth_service.dart';
import '../data/transaction_repository.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedKeys = {};
  bool _hasInitializedExpansion = false;

  static final _dayFormatter = DateFormat('EEEE, d MMMM y');
  static final _monthYearFormatter = DateFormat('MMMM y');
  static final _shortDateFormatter = DateFormat('d MMM');
  static final _timeFormatter = DateFormat('h:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final cachedTx = TransactionRepository.getCachedTransactions(user?.uid);
    final transactions = ref.watch(transactionsProvider);
    final money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: LiquidBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: transactions.when(
                loading: () {
                  if (cachedTx != null && cachedTx.isNotEmpty) {
                    return _buildTransactionContent(cachedTx, isDark, money);
                  }
                  return Center(
                    child: CircularProgressIndicator(color: AppColor.mint),
                  );
                },
                error: (error, _) => Center(
                  child: GlassCard(
                    child: Text(
                      'Could not load transactions: $error',
                      style: TextStyle(color: AppColor.text),
                    ),
                  ),
                ),
                data: (list) => _buildTransactionContent(list, isDark, money),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF090E1C).withValues(alpha: 0.75)
                          : const Color(0xFFF0F3F8).withValues(alpha: 0.82),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: AppHeader(
                        title: 'Activity',
                        subtitle: 'Your recent activity',
                        showDateBadge: false,
                        trailing: IconButton(
                          onPressed:
                              widget.onAdd ??
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionContent(
    List<AppTransaction> list,
    bool isDark,
    NumberFormat money,
  ) {
    // Collect available years and months from actual transaction data
    final availableYears = list.map((t) => t.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    final availableMonths = (list.where(
      (t) => _selectedYear == null || t.date.year == _selectedYear,
    )).map((t) => t.date.month).toSet().toList()..sort();

    // Reset selected month if no longer available in filtered year
    if (_selectedMonth != null && !availableMonths.contains(_selectedMonth)) {
      _selectedMonth = null;
    }

    final searchQuery = _searchController.text.trim().toLowerCase();

    // Filter transactions based on type, year, month, and search query
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
      if (searchQuery.isNotEmpty) {
        final noteMatch = transaction.note.toLowerCase().contains(searchQuery);
        final catMatch = transaction.category.toLowerCase().contains(searchQuery);
        final amountMatch = transaction.amount.toString().contains(searchQuery) ||
            money.format(transaction.amount).toLowerCase().contains(searchQuery);
        if (!noteMatch && !catMatch && !amountMatch) return false;
      }
      return true;
    }).toList();

    // Group and sort transactions
    final groups = _buildGroups(filtered);

    if (!_hasInitializedExpansion) {
      _expandedKeys.clear();
      if (groups.isNotEmpty) {
        _expandedKeys.add(groups.first.key);
      }
      _hasInitializedExpansion = true;
    }

    if (searchQuery.isNotEmpty) {
      _expandedKeys.addAll(groups.map((g) => g.key));
    }

    final headerWidgets = <Widget>[
      // Segmented Button: All / Expense / Income
      SegmentedButton<TransactionFilter>(
        segments: const [
          ButtonSegment(value: TransactionFilter.all, label: Text('All')),
          ButtonSegment(value: TransactionFilter.expenses, label: Text('Expense')),
          ButtonSegment(value: TransactionFilter.income, label: Text('Income')),
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
      const SizedBox(height: 12),
      // Simple, modern search field
      Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchController.text.isNotEmpty
                ? AppColor.mint.withValues(alpha: 0.5)
                : AppColor.border,
            width: 0.8,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              if (val.trim().isNotEmpty) {
                _expandedKeys.addAll(groups.map((g) => g.key));
              }
            });
          },
          style: TextStyle(
            color: AppColor.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search payments, notes, or amounts...',
            hintStyle: TextStyle(color: AppColor.muted, fontSize: 12.5),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 19,
              color: _searchController.text.isNotEmpty
                  ? AppColor.mint
                  : AppColor.muted,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColor.muted,
                    ),
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 11,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Summary bar with Expand all / Collapse all toggle
      if (groups.isNotEmpty) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'payment' : 'payments'}',
              style: TextStyle(
                color: AppColor.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  final allExpanded = _expandedKeys.length >= groups.length;
                  if (allExpanded) {
                    _expandedKeys.clear();
                  } else {
                    _expandedKeys.addAll(groups.map((g) => g.key));
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _expandedKeys.length >= groups.length
                          ? Icons.unfold_less_rounded
                          : Icons.unfold_more_rounded,
                      size: 14,
                      color: AppColor.mint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expandedKeys.length >= groups.length
                          ? 'Collapse all'
                          : 'Expand all',
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
        const SizedBox(height: 8),
      ],
    ];

    final totalItems =
        headerWidgets.length +
        (list.isEmpty || groups.isEmpty ? 1 : groups.length);

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  searchQuery.isNotEmpty
                      ? Icons.search_off_rounded
                      : Icons.filter_list_off_rounded,
                  color: AppColor.muted,
                  size: 32,
                ),
                const SizedBox(height: 12),
                heading(
                  searchQuery.isNotEmpty
                      ? 'No matching payments'
                      : 'No transactions found',
                  16,
                ),
                const SizedBox(height: 6),
                secondary(
                  searchQuery.isNotEmpty
                      ? 'No payments found matching "${_searchController.text.trim()}".'
                      : _selectedMonth != null || _selectedYear != null
                          ? 'No transactions found for the selected filter.'
                          : _filter == TransactionFilter.income
                              ? 'No income transactions found.'
                              : 'No expense transactions found.',
                ),
                if (searchQuery.isNotEmpty ||
                    _selectedMonth != null ||
                    _selectedYear != null) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _selectedYear = null;
                        _selectedMonth = null;
                        _hasInitializedExpansion = false;
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
        final isExpanded = _expandedKeys.contains(group.key);

        final previewItems = group.transactions
            .map((t) => t.note.trim().isNotEmpty ? t.note.trim() : t.category)
            .toSet()
            .take(2)
            .join(', ');

        IconData headerIcon;
        Color headerIconColor;
        if (group.title == 'Today') {
          headerIcon = Icons.bolt_rounded;
          headerIconColor = AppColor.mint;
        } else if (group.title == 'Yesterday') {
          headerIcon = Icons.history_rounded;
          headerIconColor = const Color(0xFF60A5FA);
        } else if (_groupBy == GroupByMode.month) {
          headerIcon = Icons.calendar_month_rounded;
          headerIconColor = const Color(0xFFA78BFA);
        } else if (_groupBy == GroupByMode.year) {
          headerIcon = Icons.auto_graph_rounded;
          headerIconColor = const Color(0xFFFBBF24);
        } else {
          headerIcon = Icons.calendar_today_rounded;
          headerIconColor = AppColor.mint;
        }

        return Padding(
          key: ValueKey(group.key),
          padding: const EdgeInsets.only(bottom: 11),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF111726).withValues(alpha: 0.90)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isExpanded
                    ? AppColor.mint.withValues(alpha: isDark ? 0.35 : 0.45)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: 1,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expandedKeys.remove(group.key);
                      } else {
                        _expandedKeys.add(group.key);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: headerIconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: headerIconColor.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              headerIcon,
                              color: headerIconColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.title,
                                  style: TextStyle(
                                    color: AppColor.text,
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        _groupBy == GroupByMode.year ? 15.5 : 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${group.transactions.length} ${group.transactions.length == 1 ? 'transaction' : 'transactions'}',
                                      style: TextStyle(
                                        color: AppColor.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!isExpanded && previewItems.isNotEmpty) ...[
                                      Text(
                                        ' · ',
                                        style: TextStyle(
                                          color: AppColor.muted.withValues(alpha: 0.6),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          previewItems,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColor.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Summary amounts - clean coral/mint badges without redundant 0.00
                          if (group.totalExpense > 0 && group.totalIncome > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '- ${money.format(group.totalExpense)}',
                                  style: TextStyle(
                                    color: AppColor.coral,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '+ ${money.format(group.totalIncome)}',
                                  style: TextStyle(
                                    color: AppColor.mint,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          else if (group.totalExpense > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColor.coral.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '- ${money.format(group.totalExpense)}',
                                style: TextStyle(
                                  color: AppColor.coral,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else if (group.totalIncome > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColor.mint.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+ ${money.format(group.totalIncome)}',
                                style: TextStyle(
                                  color: AppColor.mint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? AppColor.mint.withValues(alpha: 0.14)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: isExpanded ? AppColor.mint : AppColor.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Column(
                      children: [
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        for (int i = 0; i < group.transactions.length; i++) ...[
                          _transactionTile(
                            group.transactions[i],
                            money,
                            showDateInSubtitle: _groupBy != GroupByMode.date,
                          ),
                          if (i < group.transactions.length - 1)
                            Divider(
                              height: 1,
                              indent: 66,
                              endIndent: 14,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.04),
                            ),
                        ],
                        const SizedBox(height: 3),
                      ],
                    ),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 220),
                    firstCurve: Curves.easeInOutCubic,
                    secondCurve: Curves.easeInOutCubic,
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortAndFilterCard(
    List<int> availableYears,
    List<int> availableMonths,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter = _selectedYear != null || _selectedMonth != null;

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Sort by (Date / Month / Year) and Order Toggle (Newest / Oldest)
          Wrap(
            spacing: 5,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
              _buildPillChip('Date', GroupByMode.date, isDark),
              _buildPillChip('Month', GroupByMode.month, isDark),
              _buildPillChip('Year', GroupByMode.year, isDark),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                        _sortOrder == SortOrder.newestFirst
                            ? 'Newest'
                            : 'Oldest',
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
                  Icon(
                    Icons.filter_list_rounded,
                    size: 14,
                    color: AppColor.muted,
                  ),
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
                  if (_groupBy != GroupByMode.year &&
                      availableMonths.isNotEmpty) ...[
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColor.coral.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: AppColor.coral,
                            ),
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
          key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
    final timeStr = _timeFormatter.format(transaction.date);
    final subtitleDetail = showDateInSubtitle
        ? '${_shortDateFormatter.format(transaction.date)} · $timeStr'
        : timeStr;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColor.coral.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(16),
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
              side: BorderSide(color: AppColor.border, width: 1),
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
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: category.color.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: Icon(category.icon, color: category.color, size: 20),
        ),
        title: Text(
          transaction.note.isEmpty ? transaction.category : transaction.note,
          style: TextStyle(
            color: AppColor.text,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    transaction.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: category.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitleDetail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColor.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                '${transaction.isExpense ? '-' : '+'}${money.format(transaction.amount)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: transaction.isExpense ? AppColor.coral : AppColor.mint,
                ),
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
