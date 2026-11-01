import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_transaction.dart';
import '../models/weekly_budget.dart';

class TransactionRepository {
  TransactionRepository(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('transactions');

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _budgets =>
      _userDoc.collection('weeklyBudgets');

  Stream<List<AppTransaction>> watchAll() => _col
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(
              (d) => AppTransaction.fromDoc(
                d as DocumentSnapshot<Map<String, dynamic>>,
              ),
            )
            .toList(),
      );

  Future<void> add(AppTransaction t) => _col.add(t.toMap());
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

  Stream<double?> watchInitialBalance() => _userDoc.snapshots().map((doc) {
    final value = doc.data()?['initialBalance'];
    return value is num ? value.toDouble() : null;
  });

  Future<void> setInitialBalance(double amount) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(_userDoc);
      final existing = snapshot.data()?['initialBalance'];
      if (existing is num) return;
      transaction.set(_userDoc, {
        'initialBalance': amount,
      }, SetOptions(merge: true));
    });
  }
}
