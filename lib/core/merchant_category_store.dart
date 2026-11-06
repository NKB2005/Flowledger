import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MerchantCategoryStore {
  static const _prefKey = 'flow_merchant_category_rules_v1';
  static final Map<String, String> _customRules = {};
  static bool _isInitialized = false;

  /// Returns whether the store has been initialized
  static bool get isInitialized => _isInitialized;

  /// Default high-confidence merchant mappings (mostly popular Indian & global merchants)
  static final Map<String, String> _defaultRules = {
    // Food & Dining
    'swiggy': 'Food',
    'zomato': 'Food',
    'mcdonald': 'Food',
    'mcdonalds': 'Food',
    'starbucks': 'Food',
    'kfc': 'Food',
    'domino': 'Food',
    'dominos': 'Food',
    'pizza hut': 'Food',
    'burger king': 'Food',
    'subway': 'Food',
    'haldiram': 'Food',
    'chai point': 'Food',
    'chaayos': 'Food',
    'blinkit': 'Food',
    'zepto': 'Food',
    'instamart': 'Food',
    'bigbasket': 'Food',
    'dunzo': 'Food',

    // Transport & Fuel
    'uber': 'Transport',
    'ola': 'Transport',
    'rapido': 'Transport',
    'irctc': 'Transport',
    'redbus': 'Transport',
    'makemytrip': 'Transport',
    'goibibo': 'Transport',
    'ixigo': 'Transport',
    'fastag': 'Transport',
    'iocl': 'Transport',
    'bpcl': 'Transport',
    'hpcl': 'Transport',
    'shell': 'Transport',
    'indian oil': 'Transport',
    'bharat petroleum': 'Transport',
    'indigo': 'Transport',
    'air india': 'Transport',
    'vistara': 'Transport',

    // Shopping & Retail
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'ajio': 'Shopping',
    'meesho': 'Shopping',
    'nykaa': 'Shopping',
    'zara': 'Shopping',
    'h&m': 'Shopping',
    'hm': 'Shopping',
    'tata cliq': 'Shopping',
    'croma': 'Shopping',
    'reliance digital': 'Shopping',
    'dmart': 'Shopping',
    'decathlon': 'Shopping',
    'uniqlo': 'Shopping',

    // Bills & Utilities
    'bescom': 'Bills',
    'tneb': 'Bills',
    'msedcl': 'Bills',
    'upcl': 'Bills',
    'tatapower': 'Bills',
    'tata power': 'Bills',
    'bses': 'Bills',
    'adani electricity': 'Bills',
    'igl': 'Bills',
    'mgl': 'Bills',
    'jio': 'Bills',
    'airtel': 'Bills',
    'vodafone': 'Bills',
    'vi': 'Bills',
    'bsnl': 'Bills',
    'act fibernet': 'Bills',
    'hathway': 'Bills',
    'tata play': 'Bills',
    'dishtv': 'Bills',

    // Entertainment & Subscriptions
    'netflix': 'Entertainment',
    'spotify': 'Entertainment',
    'prime': 'Entertainment',
    'hotstar': 'Entertainment',
    'disney': 'Entertainment',
    'youtube': 'Entertainment',
    'pvr': 'Entertainment',
    'inox': 'Entertainment',
    'cinepolis': 'Entertainment',
    'bookmyshow': 'Entertainment',
    'steam': 'Entertainment',
    'playstation': 'Entertainment',
    'apple': 'Entertainment',

    // Health & Medical
    'apollo': 'Health',
    '1mg': 'Health',
    'pharmeasy': 'Health',
    'medplus': 'Health',
    'netmeds': 'Health',
    'practo': 'Health',
    'tata 1mg': 'Health',
  };

  /// Read-only view of custom learned rules
  static Map<String, String> get customRules => Map.unmodifiable(_customRules);

  /// Read-only view of default fallback rules
  static Map<String, String> get defaultRules => Map.unmodifiable(_defaultRules);

  /// Initializes the store from [SharedPreferences]
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      _customRules.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is String) {
              _customRules[_normalizeMerchant(key)] = value;
            }
          });
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize MerchantCategoryStore: $e');
      _isInitialized = true;
    }
  }

  /// Normalizes a merchant name for consistent lookup
  static String _normalizeMerchant(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Looks up category for a merchant.
  /// 1. Prioritizes user's learned rules.
  /// 2. Falls back to default merchant dictionary.
  /// Returns `null` if not recognized.
  static String? getCategory(String? rawMerchant) {
    if (rawMerchant == null || rawMerchant.trim().isEmpty) return null;
    final normalized = _normalizeMerchant(rawMerchant);
    if (normalized.isEmpty) return null;

    // 1. Check user custom learned rules first (exact match)
    if (_customRules.containsKey(normalized)) {
      return _customRules[normalized];
    }

    // Check user custom learned rules (substring / word boundary match)
    for (final entry in _customRules.entries) {
      if (normalized == entry.key ||
          normalized.contains(entry.key) ||
          entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    // 2. Check default built-in merchant rules
    if (_defaultRules.containsKey(normalized)) {
      return _defaultRules[normalized];
    }

    for (final entry in _defaultRules.entries) {
      if (normalized == entry.key ||
          normalized.contains(entry.key) ||
          (entry.key.length >= 4 && entry.key.split(' ').any((w) => normalized.contains(w)))) {
        return entry.value;
      }
    }

    return null;
  }

  /// Checks if a merchant rule was learned from user interactions
  static bool isLearned(String rawMerchant) {
    final normalized = _normalizeMerchant(rawMerchant);
    return _customRules.containsKey(normalized);
  }

  /// Learns and persists a merchant -> category mapping
  static Future<void> learn(String rawMerchant, String category) async {
    final normalized = _normalizeMerchant(rawMerchant);
    if (normalized.isEmpty || category.trim().isEmpty) return;

    _customRules[normalized] = category.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_customRules));
    } catch (e) {
      debugPrint('Failed to persist learned merchant category: $e');
    }
  }

  /// Removes a learned rule
  static Future<void> removeRule(String rawMerchant) async {
    final normalized = _normalizeMerchant(rawMerchant);
    if (_customRules.remove(normalized) != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, jsonEncode(_customRules));
      } catch (e) {
        debugPrint('Failed to persist merchant rule removal: $e');
      }
    }
  }

  /// Clears all user learned rules
  static Future<void> clearAllCustomRules() async {
    _customRules.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('Failed to clear merchant rules: $e');
    }
  }

  /// Test-only reset helper
  @visibleForTesting
  static void resetForTest() {
    _customRules.clear();
    _isInitialized = true;
  }
}
