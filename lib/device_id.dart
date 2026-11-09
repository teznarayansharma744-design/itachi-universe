import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Creates a short Device ID once and keeps it in secure storage.
/// The server later binds the premium key to this ID.
class DeviceId {
  static const _storage = FlutterSecureStorage();
  static const _key = 'device_id';
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static Future<String> get() async {
    var id = await _storage.read(key: _key);
    if (id == null) {
      final rnd = Random.secure();
      String part() =>
          List.generate(4, (_) => _chars[rnd.nextInt(_chars.length)]).join();
      id = '${part()}-${part()}-${part()}';
      await _storage.write(key: _key, value: id);
    }
    return id;
  }
}
