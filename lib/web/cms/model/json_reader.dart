/// Tolerant reader over decoded JSON.
///
/// Content comes from a database an admin edits, so it can be missing, the wrong
/// type, or from an older schema. Every accessor therefore returns a fallback
/// instead of throwing: a bad field degrades to its default rather than taking
/// the public page down. (Strictness belongs on the write path, where the
/// editor and the database both validate.)
class J {
  const J(this.raw);

  /// Wraps [v] if it is a map, otherwise an empty reader.
  factory J.of(Object? v) =>
      J(v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{});

  final Map<String, dynamic> raw;

  bool has(String k) => raw.containsKey(k);

  String str(String k, [String fallback = '']) {
    final v = raw[k];
    return v is String ? v : fallback;
  }

  String? strOrNull(String k) {
    final v = raw[k];
    return v is String && v.isNotEmpty ? v : null;
  }

  bool flag(String k, [bool fallback = false]) {
    final v = raw[k];
    return v is bool ? v : fallback;
  }

  double dbl(String k, [double fallback = 0]) {
    final v = raw[k];
    return v is num ? v.toDouble() : fallback;
  }

  int integer(String k, [int fallback = 0]) {
    final v = raw[k];
    return v is num ? v.toInt() : fallback;
  }

  J obj(String k) => J.of(raw[k]);

  /// Parses each map element of the list at [k]; elements that are not maps, or
  /// whose parser throws, are skipped.
  List<T> list<T>(String k, T Function(J) parse) {
    final v = raw[k];
    if (v is! List) return const [];
    final out = <T>[];
    for (final item in v) {
      if (item is! Map) continue;
      try {
        out.add(parse(J.of(item)));
      } catch (_) {
        // One bad item must not hide its siblings.
      }
    }
    return out;
  }

  /// A list of plain strings; non-strings are skipped.
  List<String> strings(String k) {
    final v = raw[k];
    if (v is! List) return const [];
    return [for (final e in v) if (e is String) e];
  }
}
