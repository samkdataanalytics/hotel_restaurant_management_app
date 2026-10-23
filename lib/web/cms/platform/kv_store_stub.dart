/// Non-web store: lives for the life of the process. Lets tests and native
/// builds exercise the same code path as the browser.
class KvStore {
  KvStore();

  static final _data = <String, String>{};

  String? read(String key) => _data[key];

  void write(String key, String value) => _data[key] = value;

  void remove(String key) => _data.remove(key);
}
