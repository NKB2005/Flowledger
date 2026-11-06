import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_colors.dart';
import 'core/auth_service.dart';
import 'core/bank_sms_parser.dart';
import 'core/bank_sms_service.dart';
import 'core/expense_store.dart';
import 'core/merchant_category_store.dart';
import 'core/profile_image_store.dart';
import 'data/transaction_repository.dart';
import 'models/app_transaction.dart';
import 'pages/auth_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/insights_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';
import 'pages/splash_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/transactions_screen.dart';
import 'widgets/category_picker_sheet.dart';
import 'widgets/glass_dock.dart';
import 'widgets/glass_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    firebaseReady = true;
  } catch (_) {}
  await AuthService.initializeGoogleSignIn();
  await AppColor.loadAppearance();
  await MerchantCategoryStore.init();
  try {
    final curUser = FirebaseAuth.instance.currentUser;
    if (curUser != null) {
      await TransactionRepository.preload(curUser.uid);
    }
  } catch (_) {}
  runApp(
    ProviderScope(
      child: ExpenseTrackerApp(
        firebaseReady: firebaseReady,
        showInitialSplash: true,
      ),
    ),
  );
}

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({
    super.key,
    this.firebaseReady,
    this.showInitialSplash = false,
  });

  final bool? firebaseReady;
  final bool showInitialSplash;

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.showInitialSplash;
  }

  void _setTheme(bool isDarkMode) {
    AppColor.setDarkMode(isDarkMode);
    setState(() {});
    unawaited(AppColor.saveAppearance());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppColor.revision,
    builder: (context, child) => MaterialApp(
      title: 'FlowLedger',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      // Keep every surface in sync when the user toggles appearance rapidly.
      themeAnimationDuration: Duration.zero,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F3F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.mint,
          brightness: Brightness.light,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: SmoothPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090E1C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColor.mint,
          brightness: Brightness.dark,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: SmoothPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: AppColor.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      onGenerateRoute: (settings) {
        if (settings.name == '/profile') {
          return PageRouteBuilder<void>(
            settings: settings,
            opaque: true,
            pageBuilder: (_, _, _) => const ProfilePage(),
            transitionsBuilder: (_, animation, _, child) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              final slide = Tween<Offset>(
                begin: const Offset(.06, 0),
                end: Offset.zero,
              ).animate(curvedAnimation);
              return FadeTransition(
                opacity: curvedAnimation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 280),
            reverseTransitionDuration: const Duration(milliseconds: 220),
          );
        }
        return null;
      },
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _showSplash
            ? FlowLedgerSplashScreen(
                key: const ValueKey('splash'),
                onFinished: () {
                  if (mounted) {
                    setState(() => _showSplash = false);
                  }
                },
              )
            : (widget.firebaseReady == null
                  ? ExpenseTrackerShell(
                      key: const ValueKey('shell'),
                      isDarkMode: AppColor.isDarkMode,
                      onThemeChanged: _setTheme,
                    )
                  : AuthGate(
                      key: const ValueKey('authGate'),
                      firebaseReady: widget.firebaseReady!,
                      isDarkMode: AppColor.isDarkMode,
                      onThemeChanged: _setTheme,
                    )),
      ),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.firebaseReady,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final bool firebaseReady;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges = AuthService().authStateChanges;
  StreamSubscription<User?>? _authSubscription;
  User? _currentUser;
  bool _isLoading = true;
  bool _showPostAuthSplash = false;

  @override
  void initState() {
    super.initState();
    if (widget.firebaseReady) {
      _authSubscription = _authStateChanges.listen((user) {
        final wasLoggedOut = _currentUser == null && !_isLoading;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentUser = user;
            if (wasLoggedOut && user != null) {
              _showPostAuthSplash = true;
            }
          });
        }
      });
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseReady) {
      return ExpenseTrackerShell(
        isDarkMode: AppColor.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColor.bg,
        body: Center(child: CircularProgressIndicator(color: AppColor.mint)),
      );
    }

    if (_currentUser == null) {
      return const AuthPage(key: ValueKey('authPage'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showPostAuthSplash
          ? FlowLedgerSplashScreen(
              key: const ValueKey('postAuthSplash'),
              onFinished: () {
                if (mounted) {
                  setState(() => _showPostAuthSplash = false);
                }
              },
            )
          : ExpenseTrackerShell(
              key: ValueKey(_currentUser!.uid),
              userId: _currentUser!.uid,
              isDarkMode: AppColor.isDarkMode,
              onThemeChanged: widget.onThemeChanged,
            ),
    );
  }
}

class ExpenseTrackerShell extends StatefulWidget {
  const ExpenseTrackerShell({
    super.key,
    this.userId,
    required this.isDarkMode,
    required this.onThemeChanged,
  });
  final String? userId;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  @override
  State<ExpenseTrackerShell> createState() => _ExpenseTrackerShellState();
}

class _ExpenseTrackerShellState extends State<ExpenseTrackerShell> {
  final ValueNotifier<int> _selectedTabNotifier = ValueNotifier<int>(0);
  late final PageController _pageController = PageController(initialPage: 0);
  late final _store = ExpenseStore(userId: widget.userId);
  late List<Widget> _pages;

  void _initPages() {
    _pages = [
      _KeepAliveTab(
        key: const ValueKey('tab_dashboard'),
        child: DashboardPage(store: _store, onSeeAll: () => _selectPage(1)),
      ),
      _KeepAliveTab(
        key: const ValueKey('tab_transactions'),
        child: TransactionsScreen(onAdd: () => _selectPage(2)),
      ),
      _KeepAliveTab(
        key: const ValueKey('tab_add'),
        child: AddTransactionScreen(onSaved: () => _selectPage(1)),
      ),
      _KeepAliveTab(
        key: const ValueKey('tab_insights'),
        child: const InsightsPage(),
      ),
      _KeepAliveTab(
        key: const ValueKey('tab_settings'),
        child: SettingsPage(
          userId: widget.userId,
          isDarkMode: AppColor.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          onLogOut: () {
            BankSmsService.stopListening();
            return AuthService().signOut();
          },
        ),
      ),
    ];
  }

  void _selectPage(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (index == _selectedTabNotifier.value) return;
    _selectedTabNotifier.value = index;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  void initState() {
    super.initState();
    LiquidBackground.hasShellBackground = true;
    _initPages();
    _store.load();
    ProfileImageStore.load(userId: widget.userId);
    MerchantCategoryStore.init();
    TransactionRepository.preload(widget.userId);
    _initSmsSync();
  }

  @override
  void didUpdateWidget(covariant ExpenseTrackerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isDarkMode != widget.isDarkMode) {
      _initPages();
      _store.load();
      ProfileImageStore.load(userId: widget.userId);
      TransactionRepository.preload(widget.userId);
      _initSmsSync();
      setState(() {});
    }
  }

  Future<void> _initSmsSync() async {
    final enabled = await BankSmsService.isAutoSyncEnabled(
      userId: widget.userId,
    );
    if (!enabled || !mounted) {
      BankSmsService.stopListening();
      return;
    }
    final hasPermission = await BankSmsService.checkPermission();
    if (!hasPermission || !mounted) {
      BankSmsService.stopListening();
      return;
    }

    BankSmsService.startListening(
      userId: widget.userId,
      getRepo: () =>
          widget.userId == null ? null : TransactionRepository(widget.userId!),
      onAutoLogged: (parsed) {
        if (!mounted) return;
        _handleAutoLogged(parsed);
      },
    );

    BankSmsService.setMethodCallHandler((call) async {
      if (call.method == 'onCategorizePaymentIntent') {
        final args = call.arguments;
        if (args is Map && mounted) {
          _handleCategorizeFromIntent(Map<String, dynamic>.from(args));
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingNotificationIntent();
    });
  }

  Future<void> _checkPendingNotificationIntent() async {
    final pending = await BankSmsService.getPendingCategorizeTransaction();
    if (pending != null && mounted) {
      _handleCategorizeFromIntent(pending);
    }
  }

  Future<void> _handleCategorizeFromIntent(Map<String, dynamic> data) async {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final merchant = data['merchant']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'Other';
    final isExpense = data['isExpense'] == true;
    final transactionId = data['transactionId']?.toString();

    final parsed = ParsedBankSms(
      amount: amount,
      isExpense: isExpense,
      category: category,
      note: merchant,
      paymentMethod: 'Bank / UPI',
      rawMessage: 'Payment detected for $merchant',
      sender: 'BANK',
      isConfident: false,
      date: DateTime.now(),
      transactionId: transactionId?.isNotEmpty == true ? transactionId : null,
    );

    await _showCategoryPickerForSms(parsed);
  }

  Future<void> _handleAutoLogged(ParsedBankSms parsed) async {
    // Show Android system notification so user can tap it from anywhere
    unawaited(BankSmsService.showPaymentNotification(parsed));

    final type = parsed.isExpense ? 'Expense' : 'Income';
    final symbol = parsed.isExpense ? '-' : '+';
    final isConf = parsed.isConfident;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        backgroundColor: AppColor.card,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: (isConf ? AppColor.mint : AppColor.coral).withValues(
              alpha: 0.6,
            ),
            width: 1.2,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isConf
                  ? (parsed.isExpense
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded)
                  : Icons.help_outline_rounded,
              color: isConf
                  ? (parsed.isExpense ? AppColor.coral : AppColor.mint)
                  : Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConf
                        ? 'Auto-logged $type · ${parsed.category}'
                        : 'New $type detected · Category needed',
                    style: TextStyle(
                      color: isConf ? AppColor.muted : Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${parsed.note}  ·  $symbol₹${parsed.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColor.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: isConf ? 'Change' : 'Categorize',
          textColor: AppColor.mint,
          onPressed: () => _showCategoryPickerForSms(parsed),
        ),
        duration: Duration(seconds: isConf ? 5 : 9),
      ),
    );
  }

  Future<void> _showCategoryPickerForSms(ParsedBankSms parsed) async {
    final chosen = await CategoryPickerSheet.show(
      context: context,
      merchant: parsed.note,
      amount: parsed.amount,
      isExpense: parsed.isExpense,
      currentCategory: parsed.category,
    );
    if (chosen != null && mounted) {
      await MerchantCategoryStore.learn(parsed.note, chosen);
      final txId = parsed.transactionId;
      if (widget.userId != null && txId != null) {
        final repo = TransactionRepository(widget.userId!);
        await repo.update(
          AppTransaction(
            id: txId,
            amount: parsed.amount,
            isExpense: parsed.isExpense,
            category: chosen,
            note: parsed.note,
            paymentMethod: parsed.paymentMethod,
            date: parsed.date,
          ),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
            backgroundColor: AppColor.card,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColor.mint.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColor.mint,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Updated to $chosen! FlowLedger will remember this for "${parsed.note}".',
                    style: TextStyle(
                      color: AppColor.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    LiquidBackground.hasShellBackground = false;
    BankSmsService.stopListening();
    _selectedTabNotifier.dispose();
    _pageController.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppColor.revision,
      builder: (context, child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColor.bg,
          body: Stack(
            children: [
              // Static ambient background behind all tabs (prevents GPU re-rastering on swipe)
              if (AppColor.showAmbientBackground)
                Positioned.fill(
                  key: const ValueKey('ambient-background'),
                  child: RepaintBoundary(
                    child: LiquidBackground(
                      standalone: true,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              Positioned.fill(
                key: const ValueKey('tab-page-view'),
                child: PageView(
                  controller: _pageController,
                  allowImplicitScrolling: true,
                  physics: const BouncingScrollPhysics(
                    parent: PageScrollPhysics(),
                  ),
                  onPageChanged: (index) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    if (_selectedTabNotifier.value != index) {
                      _selectedTabNotifier.value = index;
                    }
                  },
                  children: _pages,
                ),
              ),
              Align(
                key: const ValueKey('tab-dock'),
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _selectedTabNotifier,
                      builder: (context, selectedIndex, child) => GlassDock(
                        selected: selectedIndex,
                        onSelect: _selectPage,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SensitivePageScrollPhysics extends PageScrollPhysics {
  const SensitivePageScrollPhysics({super.parent});

  @override
  SensitivePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SensitivePageScrollPhysics(parent: buildParent(ancestor));
  }

  // Telegram-style snappy, critically damped spring
  static const _spring = SpringDescription(
    mass: 0.30,
    stiffness: 340.0,
    damping: 30.0,
  );

  @override
  SpringDescription get spring => _spring;

  @override
  double? get dragStartDistanceMotionThreshold => 0.5;

  @override
  double get minFlingVelocity => 80.0;

  @override
  double get minFlingDistance => 8.0;
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({super.key, required this.child});
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _KeepAliveTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideIn = Tween<Offset>(
      begin: const Offset(0.06, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.03, 0.0),
    ).animate(secondaryCurved);

    final fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(secondaryCurved);

    return SlideTransition(
      position: slideOut,
      child: FadeTransition(
        opacity: fadeOut,
        child: SlideTransition(
          position: slideIn,
          child: FadeTransition(opacity: fadeIn, child: child),
        ),
      ),
    );
  }
}
