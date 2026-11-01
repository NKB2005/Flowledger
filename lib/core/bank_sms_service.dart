import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/transaction_repository.dart';
import 'bank_sms_parser.dart';

class BankSmsService {
  static const _methodChannel = MethodChannel('com.example.flutter_application_1/sms_channel');
  static const _eventChannel = EventChannel('com.example.flutter_application_1/sms_stream');
  static const _prefKey = 'bank_sms_sync_enabled';

  static StreamSubscription? _smsSubscription;
  static bool _isListening = false;
  static String? _activeUserId;
  static final Set<String> _processedHashes = {};

  static bool get isListening => _isListening;
  static String? get activeUserId => _activeUserId;

  static String _keyForUser(String? userId) {
    final clean = userId?.trim();
    if (clean == null || clean.isEmpty) {
      return '${_prefKey}_guest';
    }
    return '${_prefKey}_$clean';
  }

  /// Loads whether user has enabled auto bank SMS sync in preferences for [userId].
  /// Returns `false` by default (manual opt-in required per account).
  static Future<bool> isAutoSyncEnabled({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefKey)) {
      await prefs.remove(_prefKey);
    }
    final key = _keyForUser(userId);
    return prefs.getBool(key) ?? false;
  }

  /// Sets auto sync preference for [userId].
  static Future<void> setAutoSyncEnabled(bool enabled, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_prefKey)) {
      await prefs.remove(_prefKey);
    }
    final key = _keyForUser(userId);
    await prefs.setBool(key, enabled);
  }

  /// Checks if SMS permissions (RECEIVE_SMS & READ_SMS) are granted on Android
  static Future<bool> checkPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final granted = await _methodChannel.invokeMethod<bool>('checkSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests SMS permissions from user
  static Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final granted = await _methodChannel.invokeMethod<bool>('requestSmsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts listening to real-time incoming SMS for [userId]
  static void startListening({
    String? userId,
    required TransactionRepository? Function() getRepo,
    void Function(ParsedBankSms)? onAutoLogged,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (_isListening && _activeUserId == userId) return;
    if (_isListening) {
      stopListening();
    }
    _activeUserId = userId;

    try {
      _smsSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) async {
          if (event is Map) {
            final sender = event['sender']?.toString() ?? '';
            final body = event['body']?.toString() ?? '';
            final tsRaw = event['timestamp'];
            final timestamp = tsRaw is int
                ? DateTime.fromMillisecondsSinceEpoch(tsRaw)
                : DateTime.now();

            final repo = getRepo();
            if (repo == null) return;

            final parsed = await processMessage(
              body: body,
              sender: sender,
              timestamp: timestamp,
              repo: repo,
            );

            if (parsed != null && onAutoLogged != null) {
              onAutoLogged(parsed);
            }
          }
        },
        onError: (err) {
          debugPrint('SMS stream error: $err');
        },
      );
      _isListening = true;
    } catch (e) {
      debugPrint('Failed to start SMS listener: $e');
    }
  }

  /// Stops real-time SMS listening
  static void stopListening() {
    _smsSubscription?.cancel();
    _smsSubscription = null;
    _isListening = false;
    _activeUserId = null;
  }

  /// Parses and processes a message body. If it is a new bank transaction, saves it to Firestore.
  static Future<ParsedBankSms?> processMessage({
    required String body,
    required String sender,
    DateTime? timestamp,
    required TransactionRepository repo,
  }) async {
    final parsed = BankSmsParser.parse(body, sender: sender, timestamp: timestamp);
    if (parsed == null) return null;

    // Deduplication key: amount + isExpense + note + date minute
    final dateMinute = parsed.date.millisecondsSinceEpoch ~/ 60000;
    final hash = '${parsed.amount}_${parsed.isExpense}_${parsed.note}_$dateMinute';

    if (_processedHashes.contains(hash)) {
      return null; // Already logged
    }
    _processedHashes.add(hash);
    if (_processedHashes.length > 500) {
      _processedHashes.clear();
    }

    try {
      await repo.add(parsed.toAppTransaction());
      return parsed;
    } catch (e) {
      debugPrint('Error saving auto-detected SMS transaction to Firestore: $e');
      return null;
    }
  }

  /// Reads recent bank SMS from inbox (if permission granted) and returns parsed transactions
  static Future<List<ParsedBankSms>> scanRecentBankSms({int limit = 30}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];

    try {
      final rawList = await _methodChannel.invokeListMethod<Map>('getRecentBankSms', {'limit': limit});
      if (rawList == null) return [];

      final results = <ParsedBankSms>[];
      for (final item in rawList) {
        final body = item['body']?.toString() ?? '';
        final sender = item['sender']?.toString() ?? '';
        final tsRaw = item['timestamp'];
        final timestamp = tsRaw is int
            ? DateTime.fromMillisecondsSinceEpoch(tsRaw)
            : DateTime.now();

        final parsed = BankSmsParser.parse(body, sender: sender, timestamp: timestamp);
        if (parsed != null) {
          results.add(parsed);
        }
      }
      return results;
    } catch (e) {
      debugPrint('Error scanning recent SMS: $e');
      return [];
    }
  }
}
