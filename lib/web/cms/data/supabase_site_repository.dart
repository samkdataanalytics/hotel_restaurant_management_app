import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'site_repository.dart';

/// The real thing. Reads published content with the caller's own session (anon
/// for visitors) and writes only through the `site_*` functions, which check
/// `is_superadmin()` themselves.
class SupabaseSiteRepository implements SiteRepository {
  SupabaseSiteRepository([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static const bucket = 'site-media';

  DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

  Map<String, dynamic> _content(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  @override
  Future<List<PublishedDoc>> fetchPublished() async {
    final rows = await _db.from('site_documents').select('key, content, version, published_at');
    return [
      for (final r in rows)
        PublishedDoc(
          key: r['key'] as String,
          content: _content(r['content']),
          version: (r['version'] as num).toInt(),
          publishedAt: _time(r['published_at']),
        ),
    ];
  }

  @override
  Future<DraftRecord?> loadDraft(String key) async {
    final r = await _db
        .from('site_drafts')
        .select('key, content, base_version, version, updated_at')
        .eq('key', key)
        .maybeSingle();
    if (r == null) return null;
    return DraftRecord(
      key: key,
      content: _content(r['content']),
      baseVersion: (r['base_version'] as num).toInt(),
      version: (r['version'] as num).toInt(),
      updatedAt: _time(r['updated_at']),
    );
  }

  /// The functions signal a stale save with SQLSTATE 40001.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (e.code == '40001' || e.message.startsWith('conflict')) {
        throw SiteConflict(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<int> saveDraft(String key, Map<String, dynamic> content, int expected) => _guard(() async {
        final v = await _db.rpc('site_save_draft',
            params: {'p_key': key, 'p_content': content, 'p_expected': expected});
        return (v as num).toInt();
      });

  @override
  Future<int> publish(String key, String note) async {
    final v = await _db.rpc('site_publish', params: {'p_key': key, 'p_note': note});
    return (v as num).toInt();
  }

  @override
  Future<void> discardDraft(String key) async {
    await _db.rpc('site_discard_draft', params: {'p_key': key});
  }

  @override
  Future<List<RevisionInfo>> listRevisions(String key, {int limit = 50}) async {
    final rows = await _db
        .from('site_revisions')
        .select('rev, action, note, created_at, created_by')
        .eq('key', key)
        .order('rev', ascending: false)
        .limit(limit);
    return [
      for (final r in rows)
        RevisionInfo(
          rev: (r['rev'] as num).toInt(),
          action: r['action'] as String,
          note: (r['note'] as String?) ?? '',
          createdAt: _time(r['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
          createdBy: r['created_by'] as String?,
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>> revisionContent(String key, int rev) async {
    final r = await _db
        .from('site_revisions')
        .select('content')
        .eq('key', key)
        .eq('rev', rev)
        .single();
    return _content(r['content']);
  }

  @override
  Future<int> restoreRevision(String key, int rev) async {
    final v = await _db.rpc('site_restore_revision', params: {'p_key': key, 'p_rev': rev});
    return (v as num).toInt();
  }

  // ── Media ──

  MediaItem _media(Map<String, dynamic> r) => MediaItem(
        id: r['id'] as String,
        path: r['path'] as String,
        url: r['url'] as String,
        mime: r['mime'] as String,
        bytes: (r['bytes'] as num).toInt(),
        width: (r['width'] as num?)?.toInt(),
        height: (r['height'] as num?)?.toInt(),
        alt: (r['alt'] as String?) ?? '',
        originalName: (r['original_name'] as String?) ?? '',
      );

  @override
  Future<List<MediaItem>> listMedia() async {
    final rows = await _db.from('site_media').select().order('created_at', ascending: false);
    return [for (final r in rows) _media(Map<String, dynamic>.from(r))];
  }

  static String extensionFor(String mime) => switch (mime) {
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        _ => throw ArgumentError('Unsupported image type $mime'),
      };

  @override
  Future<MediaItem> uploadMedia({
    required Uint8List bytes,
    required String mime,
    required String originalName,
    int? width,
    int? height,
    String alt = '',
  }) async {
    // Content-hash name: the same file always lands on the same path, and a
    // replaced image gets a new path, so a long cache lifetime can never serve
    // a stale picture.
    final hash = sha256.convert(bytes).toString().substring(0, 24);
    final path = '$hash.${extensionFor(mime)}';

    await _db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mime, // image/jpeg, not the filename's "jpg"
            upsert: true,
            cacheControl: '31536000',
          ),
        );
    final url = _db.storage.from(bucket).getPublicUrl(path);

    final id = await _db.rpc('site_media_register', params: {
      'p_path': path,
      'p_url': url,
      'p_width': width,
      'p_height': height,
      'p_bytes': bytes.length,
      'p_mime': mime,
      'p_alt': alt,
      'p_original_name': originalName,
    });
    return MediaItem(
      id: id as String,
      path: path,
      url: url,
      mime: mime,
      bytes: bytes.length,
      width: width,
      height: height,
      alt: alt,
      originalName: originalName,
    );
  }

  @override
  Future<void> setMediaAlt(String id, String alt) async {
    await _db.rpc('site_media_set_alt', params: {'p_id': id, 'p_alt': alt});
  }

  @override
  Future<void> deleteMedia(String id) async {
    final path = await _db.rpc('site_media_delete', params: {'p_id': id});
    if (path is String && path.isNotEmpty) {
      await _db.storage.from(bucket).remove([path]);
    }
  }
}
