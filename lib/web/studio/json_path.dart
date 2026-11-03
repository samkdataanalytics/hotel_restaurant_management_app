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
  // The containers walked through, so a removal can tidy up behind itself.
  final chain = <(Object container, Object step)>[];
  for (var i = 0; i < path.length - 1; i++) {
    final step = path[i];
    final nextIsIndex = path[i + 1] is int;
    if (step is String && cur is Map) {
      final next = cur[step];
      chain.add((cur, step));
      if (next is Map || next is List) {
        cur = next as Object;
      } else {
        final created = nextIsIndex ? <dynamic>[] : <String, dynamic>{};
        cur[step] = created;
        cur = created;
      }
    } else if (step is int && cur is List && step >= 0 && step < cur.length) {
      chain.add((cur, step));
      cur = cur[step] as Object;
    } else {
      throw ArgumentError('cannot step $step into ${cur.runtimeType}');
    }
  }
  final last = path.last;
  if (last is String && cur is Map) {
    if (value == null) {
      cur.remove(last);
      _pruneEmptyMaps(chain, cur);
    } else {
      cur[last] = value;
    }
  } else if (last is int && cur is List && last >= 0 && last < cur.length) {
    cur[last] = value;
  } else {
    throw ArgumentError('cannot set $last on ${cur.runtimeType}');
  }
}

/// After a key is removed, drops maps it leaves empty (`typography: {heading: {}}`
/// becomes nothing), so resetting a setting leaves the document as if it had never
/// been set. `content` is kept even when empty: every section has one.
void _pruneEmptyMaps(List<(Object, Object)> chain, Object leaf) {
  Object child = leaf;
  for (var i = chain.length - 1; i >= 0; i--) {
    final (container, step) = chain[i];
    if (child is Map && child.isEmpty && container is Map && step is String && step != 'content') {
      container.remove(step);
      child = container;
    } else {
      return;
    }
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
