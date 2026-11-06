import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_transaction.dart';
import '../models/weekly_budget.dart';

class TransactionRepository {
  TransactionRepository(this.uid);
  final String uid;

  static final Map<String, List<AppTransaction>> _memTransactions = {};
  static final Map<String, double> _memInitialBalance = {};
  static final Map<String, double> _memNetBalance = {};

  static List<AppTransaction>? getCachedTransactions(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _memTransactions[uid];
  }

  static double? getCachedInitialBalance(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _memInitialBalance[uid];
  }

  static double? getCachedNetBalance(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    return _memNetBalance[uid];
  }

  /// Preloads cached balances and transactions into RAM for 0ms immediate startup rendering
  static Future<void> preload(String? uid) async {
    if (uid == null || uid.trim().isEmpty) return;
    final cleanUid = uid.trim();
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Initial Balance
      final init = prefs.getDouble('cached_initial_balance_$cleanUid');
      if (init != null) {
        _memInitialBalance[cleanUid] = init;
      }

      // 2. Net Balance
      final net = prefs.getDouble('cached_net_balance_$cleanUid');
      if (net != null) {
        _memNetBalance[cleanUid] = net;
      }

      // 3. Transactions List
      final rawTx = prefs.getString('cached_transactions_$cleanUid');
      if (rawTx != null && rawTx.isNotEmpty) {
        final decoded = jsonDecode(rawTx);
        if (decoded is List) {
          final list = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => AppTransaction.fromJsonMap(m))
              .toList();
          _memTransactions[cleanUid] = list;

          if (init != null && _memNetBalance[cleanUid] == null) {
            final inc = list
                .where((t) => !t.isExpense)
                .fold<double>(0, (s, t) => s + t.amount);
            final exp = list
                .where((t) => t.isExpense)
                .fold<double>(0, (s, t) => s + t.amount);
            final computedNet = init + inc - exp;
            _memNetBalance[cleanUid] = computedNet;
          }
        }
      }
    } catch (e) {
      debugPrint('Error preloading transaction cache: $e');
    }
  }

  @visibleForTesting
  static void resetMemoryCacheForTest() {
    _memTransactions.clear();
    _memInitialBalance.clear();
    _memNetBalance.clear();
  }

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('transactions');

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _budgets =>
      _userDoc.collection('weeklyBudgets');

  String get _transactionsPrefKey => 'cached_transactions_$uid';
  String get _netBalancePrefKey => 'cached_net_balance_$uid';
  String get _balancePrefKey => 'cached_initial_balance_$uid';

  Stream<List<AppTransaction>> watchAll() async* {
    final prefs = await SharedPreferences.getInstance();

    // 1. Instantly yield in-memory or locally cached transactions (0ms delay)
    var cached = _memTransactions[uid];
    if (cached == null) {
      final raw = prefs.getString(_transactionsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            cached = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => AppTransaction.fromJsonMap(m))
                .toList();
            _memTransactions[uid] = cached;
          }
        } catch (_) {}
      }
    }

    if (cached != null) {
      yield cached;
    }

    // 2. Stream live updates from Firestore and keep disk + memory cache synchronized
    await for (final snap in _col.orderBy('date', descending: true).snapshots()) {
      final list = snap.docs
          .map(
            (d) => AppTransaction.fromDoc(
              d as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();

      _memTransactions[uid] = list;

      unawaited(() async {
        try {
          final encoded = jsonEncode(list.map((t) => t.toJsonMap()).toList());
          await prefs.setString(_transactionsPrefKey, encoded);

          final init = _memInitialBalance[uid] ?? prefs.getDouble(_balancePrefKey);
          if (init != null) {
            final inc = list
                .where((t) => !t.isExpense)
                .fold<double>(0, (s, t) => s + t.amount);
            final exp = list
                .where((t) => t.isExpense)
                .fold<double>(0, (s, t) => s + t.amount);
            final net = init + inc - exp;
            _memNetBalance[uid] = net;
            await prefs.setDouble(_netBalancePrefKey, net);
          }
        } catch (_) {}
      }());

      yield list;
    }
  }

  Future<String> add(AppTransaction t) async {
    final docRef = await _col.add(t.toMap());
    return docRef.id;
  }
  Future<void> update(AppTransaction t) => _col.doc(t.id).update(t.toMap());
  Future<void> delete(String id) => _col.doc(id).delete();
  Future<void> restore(AppTransaction t) => _col.doc(t.id).set(t.toMap());

  Future<List<AppTransaction>> getAll() async {
    final snap = await _col.orderBy('date', descending: true).get();
    return snap.docs
        .map(
          (d) => AppTransaction.fromDoc(
            d as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .toList();
  }

  Future<int> addBatch(List<AppTransaction> list) async {
    // Firestore batches have a 500 operation limit
    const batchSize = 400;
    for (int i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize < list.length) ? i + batchSize : list.length;
      final sublist = list.sublist(i, end);
      final batch = FirebaseFirestore.instance.batch();
      for (final t in sublist) {
        final docRef = _col.doc();
        batch.set(docRef, t.toMap());
      }
      await batch.commit();
    }
    return list.length;
  }

  Stream<List<WeeklyBudget>> watchWeeklyBudgets() => _budgets.snapshots().map(
    (snap) => snap.docs.map((doc) => WeeklyBudget.fromDoc(doc)).toList(),
  );

  Future<void> setWeeklyBudget({
    required String category,
    required double limit,
  }) => _budgets.doc(Uri.encodeComponent(category)).set({
    'category': category,
    'limit': limit,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> deleteWeeklyBudget(String category, {String? id}) {
    final docId =
        (id != null && id.isNotEmpty) ? id : Uri.encodeComponent(category);
    return _budgets.doc(docId).delete();
  }

  Stream<double?> watchInitialBalance() async* {
    // 1. Immediately yield locally cached balance from memory or disk for instant 0ms render
    final prefs = await SharedPreferences.getInstance();
    final cached = _memInitialBalance[uid] ?? prefs.getDouble(_balancePrefKey);
    if (cached != null) {
      _memInitialBalance[uid] = cached;
      yield cached;
    }

    // 2. Stream live updates from Firestore and keep local cache synchronized
    await for (final doc in _userDoc.snapshots()) {
      final value = doc.data()?['initialBalance'];
      if (value is num) {
        final valDouble = value.toDouble();
        _memInitialBalance[uid] = valDouble;
        await prefs.setDouble(_balancePrefKey, valDouble);

        final txList = _memTransactions[uid];
        if (txList != null) {
          final inc = txList
              .where((t) => !t.isExpense)
              .fold<double>(0, (s, t) => s + t.amount);
          final exp = txList
              .where((t) => t.isExpense)
              .fold<double>(0, (s, t) => s + t.amount);
          final net = valDouble + inc - exp;
          _memNetBalance[uid] = net;
          unawaited(prefs.setDouble(_netBalancePrefKey, net));
        }

        yield valDouble;
      } else if (cached == null) {
        yield null;
      }
    }
  }

  Future<void> setInitialBalance(double amount) async {
    _memInitialBalance[uid] = amount;
    // Immediately persist locally so UI updates instantly
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_balancePrefKey, amount);

    final txList = _memTransactions[uid];
    if (txList != null) {
      final inc = txList
          .where((t) => !t.isExpense)
          .fold<double>(0, (s, t) => s + t.amount);
      final exp = txList
          .where((t) => t.isExpense)
          .fold<double>(0, (s, t) => s + t.amount);
      final net = amount + inc - exp;
      _memNetBalance[uid] = net;
      await prefs.setDouble(_netBalancePrefKey, net);
    } else {
      _memNetBalance[uid] = amount;
      await prefs.setDouble(_netBalancePrefKey, amount);
    }

    await _userDoc.set({
      'initialBalance': amount,
    }, SetOptions(merge: true));
  }
}
