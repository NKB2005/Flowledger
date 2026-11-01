import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseStore extends ChangeNotifier {
  static const _noteKey = 'latest_note';
  static const _categoryKey = 'latest_category';

  ExpenseStore({this.userId});

  final String? userId;

  String get _notePreferenceKey => _keyForUser(_noteKey);
  String get _categoryPreferenceKey => _keyForUser(_categoryKey);

  String _keyForUser(String key) => userId == null ? key : '${key}_$userId';

  String latestNote = '';
  String latestCategory = '';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    latestNote = preferences.getString(_notePreferenceKey) ?? '';
    latestCategory = preferences.getString(_categoryPreferenceKey) ?? '';
    notifyListeners();
  }

  Future<void> saveExpense({
    required String note,
    required String category,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_notePreferenceKey, note);
    await preferences.setString(_categoryPreferenceKey, category);
    latestNote = note;
    latestCategory = category;
    notifyListeners();
  }
}
