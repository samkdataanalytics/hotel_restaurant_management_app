import 'dart:convert';
import 'dart:typed_data';

import 'site_repository.dart';

/// In-memory [SiteRepository] with the same rules as the SQL functions: draft
/// versions are checked on save, publishing bumps the version and records a
/// revision, restoring writes the draft and not the live document.
///
/// Used by studio tests, and as a stand-in until the migration is applied.
class MemorySiteRepository implements SiteRepository {
  MemorySiteRepository({Iterable<PublishedDoc> published = const []}) {
    for (final p in published) {
      _published[p.key] = p;
    }
  }

  final _published = <String, PublishedDoc>{};
  final _drafts = <String, DraftRecord>{};
  final _revisions = <String, List<({RevisionInfo info, Map<String, dynamic> content})>>{};
  final _media = <MediaItem>[];

  /// Raised by every call when set, to exercise failure paths.
  Object? failWith;

  /// Calls received, in order, for assertions.
  final log = <String>[];

  Map<String, dynamic> _copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  void _enter(String call) {
    log.add(call);
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<PublishedDoc>> fetchPublished() async {
    _enter('fetchPublished');
    return _published.values.toList();
  }

  @override
  Future<DraftRecord?> loadDraft(String key) async {
    _enter('loadDraft:$key');
    return _drafts[key];
  }

  @override
  Future<int> saveDraft(String key, Map<String, dynamic> content, int expected) async {
    _enter('saveDraft:$key');
    final cur = _drafts[key];
    if (cur == null) {
      if (expected != 0) throw const SiteConflict('draft no longer exists');
      _drafts[key] = DraftRecord(
        key: key,
        content: _copy(content),
        baseVersion: _published[key]?.version ?? 0,
        version: 1,
        updatedAt: DateTime.now(),
      );
      return 1;
    }
    if (cur.version != expected) {
      throw SiteConflict('draft changed elsewhere (have ${cur.version}, expected $expected)');
    }
    _drafts[key] = DraftRecord(
      key: key,
      content: _copy(content),
      baseVersion: cur.baseVersion,
      version: cur.version + 1,
      updatedAt: DateTime.now(),
    );
    return cur.version + 1;
  }

  @override
  Future<int> publish(String key, String note) async {
    _enter('publish:$key');
    final d = _drafts[key];
    if (d == null) throw StateError('Nothing to publish for $key');
    final v = (_published[key]?.version ?? 0) + 1;
    _published[key] = PublishedDoc(
        key: key, content: _copy(d.content), version: v, publishedAt: DateTime.now());
    final list = _revisions.putIfAbsent(key, () => []);
    list.add((
      info: RevisionInfo(
          rev: list.length + 1, action: 'publish', note: note, createdAt: DateTime.now()),
      content: _copy(d.content),
    ));
    _drafts[key] = DraftRecord(
      key: key,
      content: d.content,
      baseVersion: v,
      version: d.version,
      updatedAt: d.updatedAt,
    );
    return v;
  }

  @override
  Future<void> discardDraft(String key) async {
    _enter('discardDraft:$key');
    _drafts.remove(key);
  }

  @override
  Future<List<RevisionInfo>> listRevisions(String key, {int limit = 50}) async {
    _enter('listRevisions:$key');
    final l = _revisions[key] ?? const [];
    return l.reversed.take(limit).map((e) => e.info).toList();
  }

  @override
  Future<Map<String, dynamic>> revisionContent(String key, int rev) async {
    _enter('revisionContent:$key:$rev');
    final e = (_revisions[key] ?? const []).where((r) => r.info.rev == rev);
    if (e.isEmpty) throw StateError('Revision $rev of $key does not exist');
    return _copy(e.first.content);
  }

  @override
  Future<int> restoreRevision(String key, int rev) async {
    _enter('restoreRevision:$key:$rev');
    final content = await revisionContent(key, rev);
    final cur = _drafts[key];
    final v = (cur?.version ?? 0) + 1;
    _drafts[key] = DraftRecord(
      key: key,
      content: content,
      baseVersion: cur?.baseVersion ?? _published[key]?.version ?? 0,
      version: v,
      updatedAt: DateTime.now(),
    );
    final list = _revisions.putIfAbsent(key, () => []);
    list.add((
      info: RevisionInfo(
          rev: list.length + 1,
          action: 'restore',
          note: 'Restored revision $rev',
          createdAt: DateTime.now()),
      content: _copy(content),
    ));
    return v;
  }

  @override
  Future<List<MediaItem>> listMedia() async {
    _enter('listMedia');
    return List.of(_media);
  }

  @override
  Future<MediaItem> uploadMedia({
    required Uint8List bytes,
    required String mime,
    required String originalName,
    int? width,
    int? height,
    String alt = '',
  }) async {
    _enter('uploadMedia');
    final id = 'm${_media.length + 1}';
    final item = MediaItem(
      id: id,
      path: '$id.png',
      url: 'memory://$id',
      mime: mime,
      bytes: bytes.length,
      width: width,
      height: height,
      alt: alt,
      originalName: originalName,
    );
    _media.insert(0, item);
    return item;
  }

  @override
  Future<void> setMediaAlt(String id, String alt) async {
    _enter('setMediaAlt:$id');
    final i = _media.indexWhere((m) => m.id == id);
    if (i >= 0) _media[i] = _media[i].copyWith(alt: alt);
  }

  @override
  Future<void> deleteMedia(String id) async {
    _enter('deleteMedia:$id');
    _media.removeWhere((m) => m.id == id);
  }
}
