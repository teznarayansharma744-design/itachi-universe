import 'dart:convert';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A short Device ID like A7F3-92KD-41QX that the server binds a key to.
///
/// It comes from the phone's Android ID, so clearing the app's data does NOT change it.
/// It only changes after a factory reset, or if the app is signed with a different
/// key (the build workflow keeps the signing key fixed). If the phone refuses to give
/// an Android ID, a random one is made once and kept in secure storage.
class DeviceId {
  static const _storage = FlutterSecureStorage();
  static const _key = 'device_id';
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static String? _cached;

  static String _format(List<int> bytes) {
    String part(int from) =>
        List.generate(4, (i) => _chars[bytes[from + i] % _chars.length]).join();
    return '${part(0)}-${part(4)}-${part(8)}';
  }

  static Future<String> get() async {
    if (_cached != null) return _cached!;

    try {
      final androidId = await const AndroidId().getId();
      if (androidId != null && androidId.isNotEmpty) {
        final digest = sha256.convert(utf8.encode('itachi-universe|$androidId'));
        return _cached = _format(digest.bytes);
      }
    } catch (_) {
      // fall through to the stored random id
    }

    var id = await _storage.read(key: _key);
    if (id == null) {
      final rnd = Random.secure();
      id = _format(List.generate(12, (_) => rnd.nextInt(256)));
      await _storage.write(key: _key, value: id);
    }
    return _cached = id;
  }
}
