import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/transaction_repository.dart';
import '../models/app_transaction.dart';
import '../models/weekly_budget.dart';

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

final transactionRepositoryProvider = Provider<TransactionRepository?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return uid == null ? null : TransactionRepository(uid);
});

final transactionsProvider = StreamProvider<List<AppTransaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo == null ? Stream.value(const <AppTransaction>[]) : repo.watchAll();
});

final initialBalanceProvider = StreamProvider<double?>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo == null ? Stream.value(null) : repo.watchInitialBalance();
});

final weeklyBudgetsProvider = StreamProvider<List<WeeklyBudget>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo == null ? Stream.value(const []) : repo.watchWeeklyBudgets();
});
