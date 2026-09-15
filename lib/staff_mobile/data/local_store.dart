import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// On-device storage for the offline layer.
///
/// Two boxes with different lifetimes and different failure consequences:
///   * [_cacheBox] is disposable. Losing it costs a network round trip.
///   * [_outboxBox] holds work the user believes is done. Losing it loses an
///     order, so writes to it are awaited before the UI reports success.
///
/// Everything is stored as JSON strings rather than Hive type adapters. The
/// domain entities already have `toMap`/`fromMap`, and adapters would mean
/// build_runner codegen plus a migration story every time an entity changes.
class LocalStore {
  static const _cacheBoxName = 'hotrest_staff_cache';
  static const _outboxBoxName = 'hotrest_staff_outbox';

  Box<String>? _cacheBox;
  Box<String>? _outboxBox;

  bool get isReady => _cacheBox != null && _outboxBox != null;

  /// Opens the boxes. Safe to call more than once.
  ///
  /// A corrupt box is deleted and recreated rather than left to throw on every
  /// access — cached data is disposable, and an app that will not start is a
  /// worse outcome than a cold cache. The outbox is treated the same way only
  /// because an unreadable outbox cannot be replayed anyway.
  Future<void> init() async {
    if (isReady) return;
    await Hive.initFlutter();
    _cacheBox = await _openBox(_cacheBoxName);
    _outboxBox = await _openBox(_outboxBoxName);
  }

  static Future<Box<String>> _openBox(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } catch (e) {
      debugPrint('LocalStore: box "$name" unreadable ($e) — recreating');
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name);
    }
  }

  // ─── Cache ────────────────────────────────────────────────────────────────

  /// Cache keys are scoped by property so switching property cannot show the
  /// previous tenant's menu, and so signing in elsewhere starts clean.
  static String _cacheKey(String propertyId, String key) =>
      'v1:$propertyId:$key';

  /// Stores [value] (already JSON-encodable) against [key] with a timestamp.
  Future<void> writeCache(
    String propertyId,
    String key,
    Object value,
  ) async {
    final box = _cacheBox;
    if (box == null) return;
    try {
      await box.put(
        _cacheKey(propertyId, key),
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'value': value,
        }),
      );
    } catch (e) {
      // A failed cache write must never fail the read that triggered it.
      debugPrint('LocalStore: cache write failed for $key: $e');
    }
  }

  /// Returns the cached payload and when it was stored, or null if absent.
  CachedValue? readCache(String propertyId, String key) {
    final box = _cacheBox;
    if (box == null) return null;
    final raw = box.get(_cacheKey(propertyId, key));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedValue(
        value: decoded['value'],
        savedAt: DateTime.parse(decoded['savedAt'] as String),
      );
    } catch (e) {
      debugPrint('LocalStore: cache entry for $key is unreadable: $e');
      return null;
    }
  }

  /// Drops every cached entry for one property. Used on sign-out so the next
  /// person on a shared device cannot page through the last one's data.
  Future<void> clearCacheFor(String propertyId) async {
    final box = _cacheBox;
    if (box == null) return;
    final prefix = 'v1:$propertyId:';
    final keys = box.keys.whereType<String>().where((k) => k.startsWith(prefix));
    await box.deleteAll(keys.toList());
  }

  Future<void> clearAllCache() async => _cacheBox?.clear();

  // ─── Outbox ───────────────────────────────────────────────────────────────

  /// Queued operations in the order they were created.
  ///
  /// Order matters: a second round appended to an order created in the same
  /// offline stretch must replay after the order that it belongs to.
  List<OutboxEntry> readOutbox() {
    final box = _outboxBox;
    if (box == null) return const [];

    final entries = <OutboxEntry>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        entries.add(OutboxEntry.decode(key.toString(), raw));
      } catch (e) {
        debugPrint('LocalStore: dropping unreadable outbox entry $key: $e');
      }
    }
    entries.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return entries;
  }

  /// Appends an operation. Awaited by callers before reporting success.
  Future<void> enqueue(OutboxEntry entry) async {
    final box = _outboxBox;
    if (box == null) {
      throw StateError('Offline queue is unavailable on this device');
    }
    await box.put(entry.id, entry.encode());
  }

  Future<void> remove(String id) async => _outboxBox?.delete(id);

  Future<void> update(OutboxEntry entry) async =>
      _outboxBox?.put(entry.id, entry.encode());

  Future<void> clearOutbox() async => _outboxBox?.clear();
}

class CachedValue {
  final dynamic value;
  final DateTime savedAt;

  const CachedValue({required this.value, required this.savedAt});

  Duration get age => DateTime.now().difference(savedAt);
}

/// What kind of write is queued.
enum OutboxKind {
  /// A brand new order for a table.
  createOrder,

  /// Extra items appended to an order that already exists.
  addItems,
}

/// One queued write.
class OutboxEntry {
  final String id;
  final OutboxKind kind;
  final String propertyId;
  final DateTime queuedAt;

  /// Operation payload — shape depends on [kind].
  final Map<String, dynamic> payload;

  /// How many replay attempts have failed. Used to stop retrying forever on a
  /// write that can never succeed (a deleted table, a settled order).
  final int attempts;

  /// Why the last attempt failed, surfaced to the user rather than swallowed.
  final String? lastError;

  const OutboxEntry({
    required this.id,
    required this.kind,
    required this.propertyId,
    required this.queuedAt,
    required this.payload,
    this.attempts = 0,
    this.lastError,
  });

  /// Past this many failures an entry stops being retried automatically and is
  /// surfaced for a person to decide about. Replaying forever would hammer the
  /// server and hide a permanent failure behind a spinner.
  static const maxAttempts = 5;

  bool get isBlocked => attempts >= maxAttempts;

  OutboxEntry copyWith({int? attempts, String? lastError}) => OutboxEntry(
        id: id,
        kind: kind,
        propertyId: propertyId,
        queuedAt: queuedAt,
        payload: payload,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  String encode() => jsonEncode({
        'kind': kind.name,
        'propertyId': propertyId,
        'queuedAt': queuedAt.toIso8601String(),
        'payload': payload,
        'attempts': attempts,
        'lastError': lastError,
      });

  factory OutboxEntry.decode(String id, String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return OutboxEntry(
      id: id,
      kind: OutboxKind.values.firstWhere(
        (k) => k.name == m['kind'],
        orElse: () => OutboxKind.createOrder,
      ),
      propertyId: m['propertyId'] as String? ?? '',
      queuedAt: DateTime.parse(m['queuedAt'] as String),
      payload: Map<String, dynamic>.from(m['payload'] as Map),
      attempts: (m['attempts'] as num?)?.toInt() ?? 0,
      lastError: m['lastError'] as String?,
    );
  }
}

/// Created once in main_mobile.dart and overridden into the ProviderScope, so
/// nothing has to deal with an unopened store.
final localStoreProvider = Provider<LocalStore>((ref) {
  throw UnimplementedError('localStoreProvider must be overridden at startup');
});
