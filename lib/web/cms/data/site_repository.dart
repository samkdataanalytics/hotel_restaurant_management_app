import 'dart:typed_data';

/// A document as published: what visitors see.
class PublishedDoc {
  const PublishedDoc({required this.key, required this.content, required this.version, this.publishedAt});

  final String key;
  final Map<String, dynamic> content;
  final int version;
  final DateTime? publishedAt;

  Map<String, Object?> toJson() => {
        'key': key,
        'content': content,
        'version': version,
        'publishedAt': publishedAt?.toIso8601String(),
      };

  factory PublishedDoc.fromJson(Map<String, dynamic> j) => PublishedDoc(
        key: j['key'] as String,
        content: Map<String, dynamic>.from(j['content'] as Map),
        version: (j['version'] as num).toInt(),
        publishedAt: j['publishedAt'] is String ? DateTime.tryParse(j['publishedAt'] as String) : null,
      );
}

/// The working copy a superadmin is editing.
class DraftRecord {
  const DraftRecord({
    required this.key,
    required this.content,
    required this.baseVersion,
    required this.version,
    this.updatedAt,
  });

  final String key;
  final Map<String, dynamic> content;

  /// Published version this draft started from. When the live document has moved
  /// past it, someone else published in the meantime.
  final int baseVersion;

  /// Bumped on each save; sent back as `expected` so two open editors cannot
  /// silently overwrite one another.
  final int version;
  final DateTime? updatedAt;
}

class RevisionInfo {
  const RevisionInfo({
    required this.rev,
    required this.action,
    required this.note,
    required this.createdAt,
    this.createdBy,
  });

  final int rev;

  /// `publish`, `restore` or `discard`.
  final String action;
  final String note;
  final DateTime createdAt;
  final String? createdBy;
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.path,
    required this.url,
    required this.mime,
    required this.bytes,
    this.width,
    this.height,
    this.alt = '',
    this.originalName = '',
  });

  final String id;
  final String path;
  final String url;
  final String mime;
  final int bytes;
  final int? width;
  final int? height;
  final String alt;
  final String originalName;

  MediaItem copyWith({String? alt}) => MediaItem(
        id: id,
        path: path,
        url: url,
        mime: mime,
        bytes: bytes,
        width: width,
        height: height,
        alt: alt ?? this.alt,
        originalName: originalName,
      );
}

/// Someone else saved the draft since this editor loaded it. The editor shows a
/// banner and offers to reload; it does not overwrite.
class SiteConflict implements Exception {
  const SiteConflict(this.message);
  final String message;
  @override
  String toString() => 'SiteConflict: $message';
}

/// Everything the site and the studio ask of storage. One interface so the
/// studio runs against an in-memory fake in tests and the real database in the
/// app, with no test-only branches in the studio itself.
abstract class SiteRepository {
  // ── Public ──
  /// Every published document. Runs for anonymous visitors.
  Future<List<PublishedDoc>> fetchPublished();

  // ── Studio (superadmin) ──
  Future<DraftRecord?> loadDraft(String key);

  /// Returns the new draft version. Throws [SiteConflict] when [expected] is stale.
  Future<int> saveDraft(String key, Map<String, dynamic> content, int expected);

  /// Makes the draft live. Returns the new published version.
  Future<int> publish(String key, String note);

  /// Drops the working copy; the editor falls back to the published document.
  Future<void> discardDraft(String key);

  Future<List<RevisionInfo>> listRevisions(String key, {int limit = 50});
  Future<Map<String, dynamic>> revisionContent(String key, int rev);

  /// Loads a revision into the draft (never straight to live). Returns the new
  /// draft version.
  Future<int> restoreRevision(String key, int rev);

  // ── Media ──
  Future<List<MediaItem>> listMedia();
  Future<MediaItem> uploadMedia({
    required Uint8List bytes,
    required String mime,
    required String originalName,
    int? width,
    int? height,
    String alt = '',
  });
  Future<void> setMediaAlt(String id, String alt);
  Future<void> deleteMedia(String id);
}
