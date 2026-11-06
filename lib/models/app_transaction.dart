import 'package:cloud_firestore/cloud_firestore.dart';

class AppTransaction {
  final String id;
  final double amount;
  final bool isExpense;
  final String category;
  final String note;
  final String paymentMethod;
  final DateTime date;

  const AppTransaction({
    this.id = '',
    required this.amount,
    required this.isExpense,
    required this.category,
    this.note = '',
    this.paymentMethod = 'Cash',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'isExpense': isExpense,
    'category': category,
    'note': note,
    'paymentMethod': paymentMethod,
    'date': Timestamp.fromDate(date),
  };

  Map<String, dynamic> toJsonMap() => {
    'id': id,
    'amount': amount,
    'isExpense': isExpense,
    'category': category,
    'note': note,
    'paymentMethod': paymentMethod,
    'date': date.millisecondsSinceEpoch,
  };

  factory AppTransaction.fromJsonMap(Map<String, dynamic> d) {
    final rawDate = d['date'];
    final DateTime parsedDate;
    if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return AppTransaction(
      id: d['id'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      isExpense: d['isExpense'] as bool? ?? true,
      category: d['category'] as String? ?? 'General',
      note: d['note'] as String? ?? '',
      paymentMethod: d['paymentMethod'] as String? ?? 'Cash',
      date: parsedDate,
    );
  }

  factory AppTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) {
      return AppTransaction(
        id: doc.id,
        amount: 0,
        isExpense: true,
        category: 'General',
        date: DateTime.now(),
      );
    }
    final rawDate = d['date'];
    final DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return AppTransaction(
      id: doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      isExpense: d['isExpense'] as bool? ?? true,
      category: d['category'] as String? ?? 'General',
      note: d['note'] as String? ?? '',
      paymentMethod: d['paymentMethod'] as String? ?? 'Cash',
      date: parsedDate,
    );
  }
}
