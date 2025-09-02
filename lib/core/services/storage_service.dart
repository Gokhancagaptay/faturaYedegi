// lib/core/services/storage_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      // Web için SharedPreferences kullan
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } else {
      // Mobil için Flutter Secure Storage kullan
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      // Web için SharedPreferences'dan oku
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } else {
      // Mobil için Flutter Secure Storage'dan oku
      return await _storage.read(key: _tokenKey);
    }
  }

  Future<void> deleteToken() async {
    if (kIsWeb) {
      // Web için SharedPreferences'dan sil
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } else {
      // Mobil için Flutter Secure Storage'dan sil
      await _storage.delete(key: _tokenKey);
    }
  }
}
