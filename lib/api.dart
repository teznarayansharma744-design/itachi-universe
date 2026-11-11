import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Put your Render address here before building the app for students, for example
/// 'https://itachi-api.onrender.com'. While it still contains "your-app", the app
/// runs in offline sample mode so you can look at the screens.
const defaultBaseUrl = 'https://your-app.onrender.com';

class ApiException implements Exception {
  final String message;
  final bool unauthorized;
  ApiException(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}

class AdminKey {
  final String key;
  final String deviceId;
  final String note;
  final String status; // active | expired | revoked
  final DateTime expiresAt;
  final int daysLeft;

  AdminKey.fromJson(Map<String, dynamic> j)
      : key = j['key'] as String,
        deviceId = j['device_id'] as String,
        note = (j['note'] ?? '') as String,
        status = j['status'] as String,
        expiresAt = DateTime.parse(j['expires_at'] as String).toLocal(),
        daysLeft = j['days_left'] as int;
}

class AdminStats {
  final int total, active, expired, revoked;
  AdminStats.fromJson(Map<String, dynamic> j)
      : total = j['total'] as int,
        active = j['active'] as int,
        expired = j['expired'] as int,
        revoked = j['revoked'] as int;
}

class Api {
  static const _storage = FlutterSecureStorage();

  // Values are read once at startup (see init) so screens can use them instantly.
  static String _baseUrl = defaultBaseUrl;
  static String? _adminToken;
  static String? _premiumToken;

  /// Call once before runApp.
  static Future<void> init() async {
    _baseUrl = (await _storage.read(key: 'base_url')) ?? defaultBaseUrl;
    _adminToken = await _storage.read(key: 'admin_token');
    _premiumToken = await _storage.read(key: 'premium_token');
  }

  // ---------- server address ----------
  static Future<String> baseUrl() async => _baseUrl;
  static String get baseUrlSync => _baseUrl;

  /// False while the address is still the placeholder. The app then uses sample data.
  static bool get isConfigured => !_baseUrl.contains('your-app.onrender.com');

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: 'base_url', value: _baseUrl);
  }

  // ---------- student (premium) session ----------
  static bool get hasPremiumToken => _premiumToken != null;

  /// Headers for video/PDF requests.
  static Map<String, String> get authHeaders =>
      _premiumToken == null ? {} : {'Authorization': 'Bearer $_premiumToken'};

  static Future<void> activate(String key, String deviceId) async {
    final data = await _call('POST', '/activate',
        body: {'key': key, 'device_id': deviceId});
    _premiumToken = data['token'] as String;
    await _storage.write(key: 'premium_token', value: _premiumToken);
  }

  static Future<void> clearPremium() async {
    _premiumToken = null;
    await _storage.delete(key: 'premium_token');
  }

  /// true = key still valid, false = server says it is not (revoked/expired),
  /// null = could not tell (no internet, server asleep).
  static Future<bool?> checkPremium() async {
    try {
      await _call('GET', '/me');
      return true;
    } on ApiException catch (e) {
      return e.unauthorized ? false : null;
    }
  }

  static Future<List<dynamic>> catalogJson() async {
    final data = await _call('GET', '/catalog');
    return data['batches'] as List<dynamic>;
  }

  // ---------- admin session ----------
  static Future<bool> hasAdminSession() async => _adminToken != null;

  static Future<void> adminLogin(String password) async {
    final data = await _call('POST', '/admin/login', body: {'password': password});
    _adminToken = data['token'] as String;
    await _storage.write(key: 'admin_token', value: _adminToken);
  }

  static Future<void> adminLogout() async {
    _adminToken = null;
    await _storage.delete(key: 'admin_token');
  }

  // ---------- admin calls ----------
  static Future<AdminStats> adminStats() async =>
      AdminStats.fromJson(await _call('GET', '/admin/stats'));

  static Future<List<AdminKey>> adminKeys({String q = ''}) async {
    final data = await _call('GET', '/admin/keys?q=${Uri.encodeQueryComponent(q)}');
    return (data as List)
        .map((e) => AdminKey.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminKey> createKey(String deviceId, int days, String note) async =>
      AdminKey.fromJson(await _call('POST', '/admin/keys',
          body: {'device_id': deviceId, 'days': days, 'note': note}));

  static Future<void> revokeKey(String key) =>
      _call('POST', '/admin/keys/$key/revoke');

  static Future<void> restoreKey(String key) =>
      _call('POST', '/admin/keys/$key/restore');

  static Future<void> extendKey(String key, int days) =>
      _call('POST', '/admin/keys/$key/extend', body: {'days': days});

  static Future<void> deleteKey(String key) => _call('DELETE', '/admin/keys/$key');

  // ---------- plumbing ----------
  static Future<dynamic> _call(String method, String path,
      {Map<String, dynamic>? body}) async {
    final isAdmin = path.startsWith('/admin');
    final token = isAdmin ? _adminToken : _premiumToken;
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response r;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      const timeout = Duration(seconds: 60); // free servers wake up slowly
      switch (method) {
        case 'GET':
          r = await http.get(uri, headers: headers).timeout(timeout);
        case 'DELETE':
          r = await http.delete(uri, headers: headers).timeout(timeout);
        default:
          r = await http.post(uri, headers: headers, body: encoded ?? '{}').timeout(timeout);
      }
    } on TimeoutException {
      throw ApiException('The server is waking up. Try again in a minute.');
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your internet and try again.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (r.statusCode == 401 && path != '/admin/login') {
      if (isAdmin) {
        await adminLogout();
        throw ApiException('Session expired. Please log in again.', unauthorized: true);
      }
      await clearPremium();
      throw ApiException('Your premium key is no longer valid.', unauthorized: true);
    }
    if (r.statusCode >= 400) {
      var message = 'Something went wrong (${r.statusCode}).';
      if (decoded is Map && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      }
      throw ApiException(message);
    }
    return decoded;
  }
}
