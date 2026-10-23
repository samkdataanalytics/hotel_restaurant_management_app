/// A location inside a document: map keys and list indexes, outermost first.
/// `['sections', 2, 'content', 'title']` is the title of the third section.
typedef JsonPath = List<Object>;

/// Reads the value at [path], or null when any step is missing or the wrong
/// shape. Never throws: the editor probes paths that may not exist yet.
Object? getAt(Object? root, JsonPath path) {
  Object? cur = root;
  for (final step in path) {
    if (step is String && cur is Map) {
      cur = cur[step];
    } else if (step is int && cur is List && step >= 0 && step < cur.length) {
      cur = cur[step];
    } else {
      return null;
    }
  }
  return cur;
}

/// Sets [value] at [path] inside [root], creating the maps along the way. A null
/// [value] removes a map key (so "reset to inherited" is deleting the key rather
/// than storing a null that means something different from absent).
///
/// Mutates [root]; the studio edits a private deep copy and snapshots it for undo.
void setAt(Map<String, dynamic> root, JsonPath path, Object? value) {
  if (path.isEmpty) throw ArgumentError('path must not be empty');
  Object cur = root;
  for (var i = 0; i < path.length - 1; i++) {
    final step = path[i];
    final nextIsIndex = path[i + 1] is int;
    if (step is String && cur is Map) {
      final next = cur[step];
      if (next is Map || next is List) {
        cur = next as Object;
      } else {
        final created = nextIsIndex ? <dynamic>[] : <String, dynamic>{};
        cur[step] = created;
        cur = created;
      }
    } else if (step is int && cur is List && step >= 0 && step < cur.length) {
      cur = cur[step] as Object;
    } else {
      throw ArgumentError('cannot step $step into ${cur.runtimeType}');
    }
  }
  final last = path.last;
  if (last is String && cur is Map) {
    if (value == null) {
      cur.remove(last);
    } else {
      cur[last] = value;
    }
  } else if (last is int && cur is List && last >= 0 && last < cur.length) {
    cur[last] = value;
  } else {
    throw ArgumentError('cannot set $last on ${cur.runtimeType}');
  }
}

/// Deep copy through plain maps and lists.
Map<String, dynamic> deepCopy(Map<dynamic, dynamic> m) => {
      for (final e in m.entries) e.key as String: _copyValue(e.value),
    };

Object? _copyValue(Object? v) => switch (v) {
      Map() => deepCopy(v),
      List() => [for (final x in v) _copyValue(x)],
      _ => v,
    };
