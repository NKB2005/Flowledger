import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageStore {
  static const _pathKey = 'profile_image_path';
  static final path = ValueNotifier<String?>(null);
  static String? _activeUserId;

  static String _keyForUser(String? userId) =>
      userId == null ? _pathKey : '${_pathKey}_$userId';

  static Future<void> load({String? userId}) async {
    _activeUserId = userId;
    path.value = null;
    final preferences = await SharedPreferences.getInstance();
    final imagePath = preferences.getString(_keyForUser(userId));
    if (_activeUserId == userId) path.value = imagePath;
  }

  static Future<void> save(String imagePath, {String? userId}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyForUser(userId), imagePath);
    if (_activeUserId == userId) path.value = imagePath;
  }
}
