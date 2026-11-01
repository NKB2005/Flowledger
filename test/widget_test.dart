import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/pages/auth_page.dart';
import 'package:expense_tracker/pages/dashboard_page.dart';
import 'package:expense_tracker/core/expense_store.dart';
import 'package:expense_tracker/core/profile_image_store.dart';
import 'package:expense_tracker/core/app_colors.dart';
import 'package:expense_tracker/core/bank_sms_parser.dart';
import 'package:expense_tracker/core/bank_sms_service.dart';
import 'package:expense_tracker/pages/insights_page.dart';
import 'package:expense_tracker/pages/profile_page.dart';
import 'package:expense_tracker/pages/settings_page.dart';
import 'package:expense_tracker/screens/transactions_screen.dart';
import 'package:expense_tracker/models/app_transaction.dart';
import 'package:expense_tracker/models/weekly_budget.dart';
import 'package:expense_tracker/widgets/flow_sense.dart';
import 'package:expense_tracker/widgets/glass_ui.dart';
import 'package:expense_tracker/widgets/weekly_budget_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColor.setDarkMode(true);
    AppColor.setPalette('mint');
    AppColor.dockBlur = 18;
    AppColor.dockOpacity = .24;
    AppColor.showAmbientBackground = true;
    AppColor.showDockLabels = true;
  });

  test('appearance preferences persist across app launches', () async {
    AppColor.setDarkMode(false);
    AppColor.setPalette('ocean');
    AppColor.dockBlur = 24;
    AppColor.dockOpacity = .7;
    AppColor.showAmbientBackground = false;
    AppColor.showDockLabels = false;
    await AppColor.saveAppearance();

    AppColor.setPalette('mint');
    AppColor.dockBlur = 2;
    await AppColor.loadAppearance();

    expect(AppColor.isDarkMode, isFalse);
    expect(AppColor.paletteId, 'ocean');
    expect(AppColor.dockBlur, 24);
    expect(AppColor.dockOpacity, .7);
    expect(AppColor.showAmbientBackground, isFalse);
    expect(AppColor.showDockLabels, isFalse);
  });

  testWidgets('settings update the app color palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(isDarkMode: true, onThemeChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('Ocean'), findsNothing);
    await tester.tap(find.text('Customization'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(AppColor.paletteId, 'ocean');
    expect(AppColor.mint, const Color(0xFF54C8E8));
  });

  testWidgets(
      'settings toggle dark and light mode and update text contrast',
      (tester) async {
    bool currentMode = true;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              isDarkMode: currentMode,
              onThemeChanged: (val) {
                AppColor.setDarkMode(val);
                setState(() => currentMode = val);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark mode'), findsOneWidget);
    expect(AppColor.isDarkMode, isTrue);

    // Toggle switch to light mode
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    expect(find.text('Light mode'), findsOneWidget);
    expect(AppColor.isDarkMode, isFalse);
    expect(AppColor.text, const Color(0xFF172033));
    expect(AppColor.bg, const Color(0xFFF0F3F8));
  });

  test('dashboard greeting follows the time of day', () {
    expect(dashboardGreeting(DateTime(2026, 9, 25, 9)), 'Good morning, Alex');
    expect(
      dashboardGreeting(DateTime(2026, 9, 25, 15)),
      'Good afternoon, Alex',
    );
    expect(dashboardGreeting(DateTime(2026, 9, 25, 18)), 'Good evening, Alex');
  });

  test('latest notes are isolated by account', () async {
    final firstAccount = ExpenseStore(userId: 'account-a');
    await firstAccount.saveExpense(
      note: 'First account note',
      category: 'Food',
    );

    final secondAccount = ExpenseStore(userId: 'account-b');
    await secondAccount.load();
    expect(secondAccount.latestNote, isEmpty);
    expect(secondAccount.latestCategory, isEmpty);

    final reloadedFirstAccount = ExpenseStore(userId: 'account-a');
    await reloadedFirstAccount.load();
    expect(reloadedFirstAccount.latestNote, 'First account note');
    expect(reloadedFirstAccount.latestCategory, 'Food');
  });

  test('profile images are isolated by account', () async {
    await ProfileImageStore.load(userId: 'account-a');
    await ProfileImageStore.save('first-account.png', userId: 'account-a');

    await ProfileImageStore.load(userId: 'account-b');
    expect(ProfileImageStore.path.value, isNull);
    await ProfileImageStore.save('second-account.png', userId: 'account-b');

    await ProfileImageStore.load(userId: 'account-a');
    expect(ProfileImageStore.path.value, 'first-account.png');
  });

  test(
      'bank sms auto-tracking preferences are isolated by account and off by default',
      () async {
    // Both accounts start strictly disabled
    expect(await BankSmsService.isAutoSyncEnabled(userId: 'user-alpha'), isFalse);
    expect(await BankSmsService.isAutoSyncEnabled(userId: 'user-beta'), isFalse);

    // Alpha manually turns it on
    await BankSmsService.setAutoSyncEnabled(true, userId: 'user-alpha');
    expect(await BankSmsService.isAutoSyncEnabled(userId: 'user-alpha'), isTrue);

    // Beta must remain strictly off by default
    expect(await BankSmsService.isAutoSyncEnabled(userId: 'user-beta'), isFalse);

    // Guest / null user is also isolated and off
    expect(await BankSmsService.isAutoSyncEnabled(), isFalse);
  });

  testWidgets('budget tile shows spending beyond its limit', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BudgetTile(
            'Transport',
            1,
            Colors.red,
            spent: 1250,
            limit: 1000,
          ),
        ),
      ),
    );

    expect(find.text('Rs. 250 over limit'), findsOneWidget);
  });

  testWidgets('budget tile renders delete button and calls onDelete', (tester) async {
    bool deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BudgetTile(
            'Food',
            0.5,
            Colors.green,
            spent: 500,
            limit: 1000,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();
    expect(deleted, isTrue);
  });

  test('travel budgets include transport expenses', () {
    expect(budgetCategoryMatches('Transport', 'Travel'), isTrue);
    expect(budgetCategoryMatches(' food ', 'Food'), isTrue);
    expect(budgetCategoryMatches('Shopping', 'Transport'), isFalse);
  });

  test('Flow Sense suggests a budget-based spending adjustment', () {
    final suggestion = flowSenseSuggestion(
      transactions: [
        AppTransaction(
          amount: 850,
          isExpense: true,
          category: 'Food',
          date: DateTime(2026, 9, 28),
        ),
      ],
      budgets: [const WeeklyBudget(id: 'food', category: 'Food', limit: 1000)],
      now: DateTime(2026, 9, 30),
    );

    expect(suggestion, contains('Food has Rs. 150 left'));
  });

  test('Flow Sense estimates savings from the largest category', () {
    final suggestion = flowSenseSuggestion(
      transactions: [
        AppTransaction(
          amount: 500,
          isExpense: true,
          category: 'Food',
          date: DateTime(2026, 9, 29),
        ),
        AppTransaction(
          amount: 250,
          isExpense: true,
          category: 'Transport',
          date: DateTime(2026, 9, 30),
        ),
      ],
      now: DateTime(2026, 9, 30),
    );

    expect(suggestion, contains('Food is your biggest spend this week'));
    expect(suggestion, contains('about Rs. 50'));
  });

  test('monthly calendar totals only include the selected month', () {
    final totals = monthlyTransactionTotals([
      AppTransaction(
        amount: 500,
        isExpense: true,
        category: 'Food',
        date: DateTime(2026, 9, 10),
      ),
      AppTransaction(
        amount: 2000,
        isExpense: false,
        category: 'Salary',
        date: DateTime(2026, 9, 1),
      ),
      AppTransaction(
        amount: 300,
        isExpense: true,
        category: 'Food',
        date: DateTime(2026, 8, 31),
      ),
    ], DateTime(2026, 9));

    expect(totals.expenses, 500);
    expect(totals.income, 2000);
  });

  test('transactions are grouped by day, newest day first', () {
    final grouped = groupTransactionsByDay([
      AppTransaction(
        amount: 100,
        isExpense: true,
        category: 'Food',
        date: DateTime(2026, 9, 29, 9),
      ),
      AppTransaction(
        amount: 200,
        isExpense: false,
        category: 'Salary',
        date: DateTime(2026, 9, 30, 10),
      ),
      AppTransaction(
        amount: 150,
        isExpense: true,
        category: 'Food',
        date: DateTime(2026, 9, 29, 18),
      ),
    ]);

    expect(grouped.keys.first, DateTime(2026, 9, 30));
    expect(grouped[DateTime(2026, 9, 29)], hasLength(2));
  });

  test('financial health uses monthly cash flow and weekly budget use', () {
    final health = calculateFinancialHealth(
      transactions: [
        AppTransaction(
          amount: 2000,
          isExpense: false,
          category: 'Salary',
          date: DateTime(2026, 9, 2),
        ),
        AppTransaction(
          amount: 1000,
          isExpense: true,
          category: 'Food',
          date: DateTime(2026, 9, 29),
        ),
        AppTransaction(
          amount: 680,
          isExpense: true,
          category: 'Other',
          date: DateTime(2026, 9, 29),
        ),
      ],
      budgets: [const WeeklyBudget(id: 'food', category: 'Food', limit: 1000)],
      now: DateTime(2026, 9, 30),
    );

    expect(health.score, 78);
    expect(health.status, 'On a healthy track');
  });

  test('financial health asks for income when only expenses are recorded', () {
    final health = calculateFinancialHealth(
      transactions: [
        AppTransaction(
          amount: 200,
          isExpense: true,
          category: 'Food',
          date: DateTime(2026, 9, 29),
        ),
      ],
      budgets: const [],
      now: DateTime(2026, 9, 30),
    );

    expect(health.score, isNull);
    expect(health.status, 'Add your income');
  });

  testWidgets('monthly calendar navigates and filters income or expenditure', (
    tester,
  ) async {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlySpendingCalendar(transactions: []),
          ),
        ),
      ),
    );

    expect(
      find.text(DateFormat('MMMM yyyy').format(currentMonth)),
      findsOneWidget,
    );
    final filterFinder = find.byType(
      SegmentedButton<CalendarTransactionFilter>,
    );
    expect(
      tester
          .widget<SegmentedButton<CalendarTransactionFilter>>(filterFinder)
          .selected,
      {CalendarTransactionFilter.expenditure},
    );
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<CalendarTransactionFilter>>(filterFinder)
          .selected,
      {CalendarTransactionFilter.income},
    );
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    expect(
      find.text(DateFormat('MMMM yyyy').format(previousMonth)),
      findsOneWidget,
    );
  });

  testWidgets('transactions expand by date and filter by type', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final transactions = [
      AppTransaction(
        id: 'today-expense',
        amount: 120,
        isExpense: true,
        category: 'Food',
        note: 'Coffee',
        date: today.add(const Duration(hours: 10)),
      ),
      AppTransaction(
        id: 'yesterday-income',
        amount: 1500,
        isExpense: false,
        category: 'Salary',
        note: 'Paycheck',
        date: today.subtract(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionsProvider.overrideWith(
            (ref) => Stream.value(transactions),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(
      tester
          .widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .map((crossFade) => crossFade.crossFadeState),
      [CrossFadeState.showSecond, CrossFadeState.showFirst],
    );
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .map((crossFade) => crossFade.crossFadeState),
      [CrossFadeState.showFirst, CrossFadeState.showFirst],
    );
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Paycheck'), findsOneWidget);
    expect(find.byType(AnimatedCrossFade), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showSecond,
    );
  });

  testWidgets('shows the expense tracker dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ExpenseTrackerApp()));
    expect(find.text(dashboardGreeting()), findsOneWidget);
  });

  testWidgets(
      'ambient background toggle dynamically adds and removes GlowOrbs',
      (tester) async {
    AppColor.showAmbientBackground = true;
    await tester.pumpWidget(const ProviderScope(child: ExpenseTrackerApp()));
    await tester.pumpAndSettle();

    expect(find.byType(GlowOrb), findsNWidgets(3));

    AppColor.showAmbientBackground = false;
    AppColor.revision.value++;
    await tester.pumpAndSettle();

    expect(find.byType(GlowOrb), findsNothing);

    AppColor.showAmbientBackground = true;
    AppColor.revision.value++;
    await tester.pumpAndSettle();

    expect(find.byType(GlowOrb), findsNWidgets(3));
  });

  testWidgets(
      'swiping PageView switches between tabs (Home to Activity and back)',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ExpenseTrackerApp()));
    await tester.pumpAndSettle();

    expect(find.text(dashboardGreeting()), findsOneWidget);

    // Swipe left to navigate from Home to Activity tab
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);

    // Swipe right to navigate back to Home tab
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(find.text(dashboardGreeting()), findsOneWidget);
  });

  testWidgets(
      'AuthPage displays Google sign-in button and toggles create account mode',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthPage(),
      ),
    );

    expect(find.text('Sign in with Google'), findsOneWidget);
    final createAccountFinder = find.text('Create account').first;
    await tester.ensureVisible(createAccountFinder);
    await tester.pumpAndSettle();
    await tester.tap(createAccountFinder);
    await tester.pumpAndSettle();

    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('or register with email'), findsOneWidget);
  });

  testWidgets('TransactionsScreen sorts and groups by Date, Month, and Year with order toggle', (tester) async {
    final transactions = [
      AppTransaction(
        id: 't-2025',
        amount: 500,
        isExpense: true,
        category: 'Food',
        note: 'Old Dinner',
        date: DateTime(2025, 5, 10),
      ),
      AppTransaction(
        id: 't-2026-sep',
        amount: 1000,
        isExpense: true,
        category: 'Transport',
        note: 'Flight',
        date: DateTime(2026, 9, 15),
      ),
      AppTransaction(
        id: 't-2026-oct',
        amount: 2500,
        isExpense: false,
        category: 'Salary',
        note: 'Freelance pay',
        date: DateTime(2026, 10, 20),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionsProvider.overrideWith(
            (ref) => Stream.value(transactions),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sort controls are rendered
    expect(find.text('Sort:'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);

    // Switch to Month grouping
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('May 2025'), findsOneWidget);

    // Toggle to Oldest first
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(find.text('Oldest'), findsOneWidget);

    // Switch to Year grouping
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('Year 2025'), findsOneWidget);
    expect(find.text('Year 2026'), findsOneWidget);

    // Filter by year 2026
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();

    expect(find.text('Year 2026'), findsOneWidget);
    expect(find.text('Year 2025'), findsNothing);
  });

  testWidgets(
      'TransactionsScreen renders pencil icon to edit and provides back button on edit page',
      (tester) async {
    final transactions = [
      AppTransaction(
        id: 'tx-salary-1',
        amount: 25000,
        isExpense: false,
        category: 'Salary',
        note: 'Monthly Salary',
        date: DateTime(2026, 10, 1),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionsProvider.overrideWith(
            (ref) => Stream.value(transactions),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Verify transaction is rendered
    expect(find.text('Monthly Salary'), findsOneWidget);
    // Verify pencil icon is rendered on the right side
    final pencilIcon = find.byIcon(Icons.edit_rounded);
    expect(pencilIcon, findsOneWidget);

    // Tapping the transaction title does NOT open edit screen
    await tester.tap(find.text('Monthly Salary'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsNothing);

    // Tapping the pencil icon opens edit screen
    await tester.tap(pencilIcon);
    await tester.pumpAndSettle();

    // Verify edit screen is shown
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('25000.0'), findsOneWidget);

    // Verify back button is on the app bar
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);

    // Tapping the back button returns to the activity page
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsNothing);
    expect(find.text('Monthly Salary'), findsOneWidget);
  });

  testWidgets('deleting a transaction displays an Undo snackbar',
      (tester) async {
    final transactions = [
      AppTransaction(
        id: 'tx-delete-1',
        amount: 450,
        isExpense: true,
        category: 'Food',
        note: 'Burger Lunch',
        date: DateTime(2026, 10, 2),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionsProvider.overrideWith(
            (ref) => Stream.value(transactions),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TransactionsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Burger Lunch'), findsOneWidget);

    // Swipe Dismissible to delete
    await tester.drag(find.text('Burger Lunch'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify Undo snackbar is visible
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Expense "Burger Lunch" deleted'), findsOneWidget);
  });

  group('BankSmsParser tests', () {
    test('parses debit expense with merchant and category', () {
      const sms = 'Dear UPI user A/C 9876 debited by 450.0 on 24-Oct-26 to Zomato UPI Ref 410293. Avl Bal Rs 18,240.50';
      final parsed = BankSmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 450.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.category, 'Food');
      expect(parsed.note.toLowerCase(), contains('zomato'));
      expect(parsed.paymentMethod, 'UPI');
    });

    test('parses salary credit with income detection', () {
      const sms = 'Your A/C 1234 is credited with INR 65,000.00 on 01-Nov-26 towards Salary. Clear Bal INR 85,200.00';
      final parsed = BankSmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 65000.0);
      expect(parsed.isExpense, isFalse);
      expect(parsed.category, 'Salary');
      expect(parsed.paymentMethod, 'Bank Transfer');
    });

    test('parses card fuel spend with category detection', () {
      const sms = 'Your Card ending 4321 has been debited by INR 1,200.00 on 24-Oct-26 at SHELL PETROL PUMP. Avl Bal INR 14,800.00';
      final parsed = BankSmsParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1200.0);
      expect(parsed.isExpense, isTrue);
      expect(parsed.category, 'Transport');
      expect(parsed.accountDigits, contains('4321'));
    });

    test('ignores OTP, login alerts, and non-transactions', () {
      const otpSms = 'Your OTP for transaction at Amazon is 492810. Do not share with anyone.';
      expect(BankSmsParser.parse(otpSms), isNull);

      const promoSms = 'Congratulations! You are pre-approved for personal loan up to Rs 5,00,000. Apply now.';
      expect(BankSmsParser.parse(promoSms), isNull);
    });
  });

  testWidgets('Settings page displays Bank SMS auto-tracking controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(isDarkMode: true, onThemeChanged: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bank SMS auto-tracking'), findsOneWidget);
    expect(find.textContaining('Turned off'), findsOneWidget);
    expect(find.text('Scan recent bank SMS'), findsOneWidget);
    expect(find.text('Bank SMS simulator / tester'), findsOneWidget);

    // Tapping switch asks with a confirmation dialog
    await tester.tap(find.text('Bank SMS auto-tracking'));
    await tester.pumpAndSettle();

    expect(find.text('Enable Bank SMS Sync?'), findsOneWidget);

    // Tapping Cancel keeps it off
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Enable Bank SMS Sync?'), findsNothing);
    expect(find.textContaining('Turned off'), findsOneWidget);
  });

  group('Robustness and Edge Case Verification', () {
    test('BankSmsParser handles null-like, unicode, and malformed messages safely', () {
      expect(BankSmsParser.parse(''), isNull);
      expect(BankSmsParser.parse('   '), isNull);
      expect(BankSmsParser.parse('Hello world! 🎉💰 12345'), isNull);
      expect(BankSmsParser.parse('debited with Rs 0'), isNull);
      expect(BankSmsParser.parse('paid Rs -50 to vendor'), isNull);
    });

    test('Financial Health handles zero income and budget edge cases', () {
      // 1. Both income and expenses are 0
      final health1 = calculateFinancialHealth(
        transactions: const [],
        budgets: const [],
      );
      expect(health1.score, isNull);
      expect(health1.status, 'Not enough data');

      // 2. Only expenses, zero income
      final health2 = calculateFinancialHealth(
        transactions: [
          AppTransaction(
            amount: 500,
            isExpense: true,
            category: 'Food',
            date: DateTime.now(),
          ),
        ],
        budgets: const [],
      );
      expect(health2.score, isNull);
      expect(health2.status, 'Add your income');

      // 3. Perfect savings, no budget set
      final health3 = calculateFinancialHealth(
        transactions: [
          AppTransaction(
            amount: 10000,
            isExpense: false,
            category: 'Salary',
            date: DateTime.now(),
          ),
          AppTransaction(
            amount: 2000,
            isExpense: true,
            category: 'Food',
            date: DateTime.now(),
          ),
        ],
        budgets: const [],
      );
      expect(health3.score, 100);
      expect(health3.status, 'On a healthy track');

      // 4. Overspent weekly budget reduces score
      final health4 = calculateFinancialHealth(
        transactions: [
          AppTransaction(
            amount: 10000,
            isExpense: false,
            category: 'Salary',
            date: DateTime.now(),
          ),
          AppTransaction(
            amount: 2500,
            isExpense: true,
            category: 'Food',
            date: DateTime.now(),
          ),
        ],
        budgets: const [
          WeeklyBudget(id: '1', category: 'Food', limit: 1000),
        ],
      );
      // Spent 2500 on 1000 budget => usage = 2.5 >= 1.2 => budgetScore = 0
      // cashFlowScore = 100 * 0.7 + 0 = 70
      expect(health4.score, 70);
      expect(health4.status, 'Room to improve');
    });

    test('Budget category matching is case-insensitive and normalizes synonyms', () {
      expect(budgetCategoryMatches('transport', 'Travel'), isTrue);
      expect(budgetCategoryMatches('Travel', 'Transport'), isTrue);
      expect(budgetCategoryMatches('  FOOD  ', 'food'), isTrue);
      expect(budgetCategoryMatches('Shopping', 'Bills'), isFalse);
    });
  });
}

