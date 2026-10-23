import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cms/data/site_repository.dart';
import 'json_path.dart';
import 'studio_state.dart';

typedef DefaultsLookup = Map<String, dynamic> Function(String key);
typedef Validator = List<ValidationIssue> Function(String key, Map<String, dynamic> doc);

/// Edits one document at a time: holds the working copy, undo history, autosave
/// to the draft, and publishing.
///
/// The working copy is plain JSON, and every edit is `setAt(path, value)` or a
/// list operation on `sections`. There is no typed model to keep in step with
/// the renderer's parsing: the renderer reads exactly what is edited here.
class StudioController extends StateNotifier<StudioState> {
  StudioController({
    required SiteRepository repository,
    required DefaultsLookup defaults,
    Validator? validator,
    this.autosaveDelay = const Duration(milliseconds: 1500),
    this.onPublished,
  })  : _repo = repository,
        _defaults = defaults,
        _validator = validator ?? ((_, __) => const []),
        super(const StudioState());

  final SiteRepository _repo;
  final DefaultsLookup _defaults;
  final Validator _validator;

  /// How long after the last edit the draft is saved. [Duration.zero] disables
  /// the timer (tests call [flush]).
  final Duration autosaveDelay;

  /// Called after a successful publish, so the public site's cache can refresh.
  final VoidCallback? onPublished;

  static const _undoLimit = 100;
  static const _coalesceWindow = Duration(milliseconds: 1000);

  final _undo = <String>[];
  final _redo = <String>[];
  Timer? _timer;
  int _generation = 0;

  JsonPath? _lastPath;
  DateTime _lastEditAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> open(String key) async {
    if (state.key.isNotEmpty && state.key != key) await flush();
    _timer?.cancel();
    _undo.clear();
    _redo.clear();
    _lastPath = null;
    state = StudioState(key: key, loading: true);

    PublishedDoc? published;
    DraftRecord? draft;
    String? problem;
    try {
      final all = await _repo.fetchPublished();
      published = all.where((d) => d.key == key).firstOrNull;
      draft = await _repo.loadDraft(key);
    } catch (e) {
      // Most often: the migration has not been applied, or the session is not a
      // superadmin. The editor still opens on the bundled content so it can be
      // looked at, but it says plainly that nothing will save.
      problem = _describe(e);
    }

    final base = published?.content ?? _defaults(key);
    final doc = deepCopy(draft?.content ?? base);

    state = StudioState(
      key: key,
      doc: doc,
      published: deepCopy(base),
      source: draft != null
          ? DocSource.draft
          : (published != null ? DocSource.published : DocSource.defaults),
      draftVersion: draft?.version ?? 0,
      publishedVersion: published?.version ?? 0,
      status: problem != null ? SaveStatus.error : SaveStatus.saved,
      loading: false,
      error: problem,
      selectedId: _firstSectionId(doc),
      issues: _validator(key, doc),
    );
  }

  String? _firstSectionId(Map<String, dynamic> doc) {
    final s = doc['sections'];
    if (s is List && s.isNotEmpty && s.first is Map) return (s.first as Map)['id'] as String?;
    return null;
  }

  String _describe(Object e) {
    final s = e.toString();
    if (s.contains('site_drafts') || s.contains('site_documents') || s.contains('42P01')) {
      return 'The website tables are not set up on this database. Run the site_cms migration, '
          'then reload. Edits will not be saved until then.';
    }
    if (s.contains('42501') || s.toLowerCase().contains('permission')) {
      return 'This account is not allowed to edit the website (superadmin only).';
    }
    return s;
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  bool get differsFromPublished => !const DeepCollectionEquality().equals(state.doc, state.published);

  List<Map<String, dynamic>> get _sections {
    final s = state.doc['sections'];
    return s is List ? s.whereType<Map<String, dynamic>>().toList() : const [];
  }

  int indexOfSection(String id) => _sections.indexWhere((s) => s['id'] == id);

  Map<String, dynamic>? sectionById(String id) {
    final i = indexOfSection(id);
    return i < 0 ? null : _sections[i];
  }

  // ── Editing ────────────────────────────────────────────────────────────────

  void select(String? id) => state = state.copyWith(selectedId: id);

  /// Sets the value at [path]; null removes it ("reset to inherited").
  ///
  /// Consecutive edits to the same field within a second share one undo step, so
  /// typing a sentence is one undo, not one per character.
  void edit(JsonPath path, Object? value) {
    final now = DateTime.now();
    final coalesce = _lastPath != null &&
        listEquals(_lastPath, path) &&
        now.difference(_lastEditAt) < _coalesceWindow;
    _lastPath = path;
    _lastEditAt = now;

    _mutate((doc) => setAt(doc, path, value), recordUndo: !coalesce);
  }

  void _mutate(void Function(Map<String, dynamic> doc) change, {bool recordUndo = true, String? select}) {
    final before = jsonEncode(state.doc);
    final doc = deepCopy(state.doc);
    change(doc);
    if (jsonEncode(doc) == before) return;

    if (recordUndo) {
      _undo.add(before);
      if (_undo.length > _undoLimit) _undo.removeAt(0);
    }
    _redo.clear();
    _commit(doc, selectedId: select);
  }

  void _commit(Map<String, dynamic> doc, {String? selectedId}) {
    state = state.copyWith(
      doc: doc,
      selectedId: selectedId ?? state.selectedId,
      status: state.status == SaveStatus.conflict ? SaveStatus.conflict : SaveStatus.dirty,
      canUndo: _undo.isNotEmpty,
      canRedo: _redo.isNotEmpty,
      issues: _validator(state.key, doc),
    );
    _generation++;
    _scheduleSave();
  }

  bool undo() {
    if (_undo.isEmpty) return false;
    _redo.add(jsonEncode(state.doc));
    final doc = Map<String, dynamic>.from(jsonDecode(_undo.removeLast()) as Map);
    _lastPath = null;
    _commit(deepCopy(doc));
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    _undo.add(jsonEncode(state.doc));
    final doc = Map<String, dynamic>.from(jsonDecode(_redo.removeLast()) as Map);
    _lastPath = null;
    _commit(deepCopy(doc));
    return true;
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  List<dynamic> _list(Map<String, dynamic> doc) =>
      (doc['sections'] is List ? doc['sections'] : doc['sections'] = <dynamic>[]) as List<dynamic>;

  /// A section id not used yet: `faq`, `faq-2`, `faq-3`…
  String uniqueId(String base) {
    final used = _sections.map((s) => s['id']).toSet();
    if (!used.contains(base)) return base;
    var n = 2;
    while (used.contains('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }

  /// Inserts [node] after the section [afterId], or at the end. Its id is made
  /// unique. Returns the id it ended up with.
  String addSection(Map<String, dynamic> node, {String? afterId}) {
    final id = uniqueId((node['id'] as String?) ?? (node['type'] as String));
    final copy = deepCopy(node)..['id'] = id;
    _mutate((doc) {
      final list = _list(doc);
      final i = afterId == null ? -1 : list.indexWhere((s) => s is Map && s['id'] == afterId);
      list.insert(i < 0 ? list.length : i + 1, copy);
    }, select: id);
    return id;
  }

  String? duplicateSection(String id) {
    final src = sectionById(id);
    if (src == null) return null;
    final newId = uniqueId(id);
    final copy = deepCopy(src)..['id'] = newId;
    // An anchor must stay unique on the page, or two sections answer one link.
    copy.remove('anchor');
    _mutate((doc) {
      final list = _list(doc);
      final i = list.indexWhere((s) => s is Map && s['id'] == id);
      list.insert(i + 1, copy);
    }, select: newId);
    return newId;
  }

  void removeSection(String id) {
    final i = indexOfSection(id);
    if (i < 0) return;
    final sections = _sections;
    final nextSel = sections.length > 1 ? sections[i == 0 ? 1 : i - 1]['id'] as String? : null;
    _mutate((doc) {
      _list(doc).removeWhere((s) => s is Map && s['id'] == id);
    });
    if (state.selectedId == id) state = state.copyWith(selectedId: nextSel);
  }

  /// Moves the section at [oldIndex] so that it ends up at [newIndex] in the
  /// resulting list. (This is `ReorderableListView.onReorderItem`'s convention:
  /// the index is already adjusted for the removed item.)
  void moveSection(int oldIndex, int newIndex) {
    final list = _sections;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final to = newIndex.clamp(0, list.length - 1);
    if (to == oldIndex) return;
    _mutate((doc) {
      final l = _list(doc);
      final item = l.removeAt(oldIndex);
      l.insert(to, item);
    });
  }

  void setSectionEnabled(String id, bool enabled) {
    final i = indexOfSection(id);
    if (i < 0) return;
    // Stored only when off: an enabled section carries no flag, like every
    // section that predates the editor.
    edit(['sections', i, 'enabled'], enabled ? null : false);
  }

  // ── Saving ─────────────────────────────────────────────────────────────────

  void _scheduleSave() {
    _timer?.cancel();
    if (autosaveDelay == Duration.zero || state.status == SaveStatus.conflict) return;
    _timer = Timer(autosaveDelay, () => unawaited(flush()));
  }

  /// Saves the working copy now (if there is something to save).
  Future<void> flush() async {
    _timer?.cancel();
    if (state.key.isEmpty || state.status == SaveStatus.conflict) return;
    if (state.status == SaveStatus.saved || state.loading) return;

    final gen = _generation;
    final snapshot = deepCopy(state.doc);
    state = state.copyWith(status: SaveStatus.saving, error: null);
    try {
      final v = await _repo.saveDraft(state.key, snapshot, state.draftVersion);
      // If the admin kept typing while this was in flight, the newer edit has its
      // own save scheduled; this one only advances the version.
      final stillCurrent = gen == _generation;
      state = state.copyWith(
        draftVersion: v,
        source: DocSource.draft,
        status: stillCurrent ? SaveStatus.saved : SaveStatus.dirty,
      );
      if (!stillCurrent) _scheduleSave();
    } on SiteConflict catch (e) {
      state = state.copyWith(status: SaveStatus.conflict, error: e.message);
    } catch (e) {
      state = state.copyWith(status: SaveStatus.error, error: _describe(e));
    }
  }

  /// After a conflict: throw the local state away and load what is on the server.
  Future<void> reloadFromServer() => open(state.key);

  // ── Publishing ─────────────────────────────────────────────────────────────

  /// Publishes the working copy. Returns false (with [StudioState.error] set)
  /// when validation blocks it or the save fails.
  Future<bool> publish(String note) async {
    if (state.errors.isNotEmpty) {
      state = state.copyWith(error: 'Fix the ${state.errors.length} error(s) before publishing.');
      return false;
    }
    state = state.copyWith(publishing: true, error: null);
    await flush();
    if (state.status == SaveStatus.error || state.status == SaveStatus.conflict) {
      state = state.copyWith(publishing: false);
      return false;
    }
    try {
      final v = await _repo.publish(state.key, note);
      state = state.copyWith(
        published: deepCopy(state.doc),
        publishedVersion: v,
        publishing: false,
        source: DocSource.draft,
      );
      onPublished?.call();
      return true;
    } catch (e) {
      state = state.copyWith(publishing: false, error: _describe(e));
      return false;
    }
  }

  /// Throws the working copy away and reloads from the published document.
  Future<void> discard() async {
    final key = state.key;
    _timer?.cancel();
    try {
      await _repo.discardDraft(key);
    } catch (e) {
      state = state.copyWith(error: _describe(e));
      return;
    }
    await open(key);
  }

  /// Loads a revision into the draft for review. It does not go live.
  Future<void> restoreRevision(int rev) async {
    final key = state.key;
    await flush();
    try {
      await _repo.restoreRevision(key, rev);
    } catch (e) {
      state = state.copyWith(error: _describe(e));
      return;
    }
    await open(key);
  }
}
