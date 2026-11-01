import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyBudget {
  const WeeklyBudget({
    required this.id,
    required this.category,
    required this.limit,
  });

  final String id;
  final String category;
  final double limit;

  factory WeeklyBudget.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return WeeklyBudget(
        id: doc.id,
        category: Uri.decodeComponent(doc.id),
        limit: 0.0,
      );
    }
    return WeeklyBudget(
      id: doc.id,
      category: data['category'] as String? ?? Uri.decodeComponent(doc.id),
      limit: (data['limit'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'category': category, 'limit': limit};
}
