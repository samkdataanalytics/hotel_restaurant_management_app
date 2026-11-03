import 'package:web/web.dart' as web;

/// `localStorage`, with every access guarded: it throws in private windows and
/// when site data is blocked, and a cache that cannot be written must never take
/// the page down. A failed read is just a miss.
class KvStore {
  KvStore();

  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
