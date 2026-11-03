import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../platform/kv_store.dart';
import 'site_repository.dart';
import 'supabase_site_repository.dart';

/// Holds the published documents the public site draws from.
///
/// Stale-while-revalidate: on start it publishes whatever was cached from the
/// last visit straight away (so the first frame needs no network), then fetches
/// the current set and swaps it in if it succeeds. Every failure — no network,
/// the table missing, a slow or paused database — leaves what is already there
/// untouched, so the worst case is the bundled defaults, never a blank page.
///
/// Started from `main()`, in parallel with the rest of start-up: the engine boot
/// is the long pole, and the fetch should already be in flight when the first
/// frame is built.
class SiteContentStore {
  SiteContentStore({
    KvStore? kv,
    SiteRepository Function()? repository,
    this.timeout = const Duration(seconds: 4),
  })  : _kv = kv ?? KvStore(),
        _repository = repository ?? SupabaseSiteRepository.new;

  /// The app-wide instance. Tests build their own.
  static final instance = SiteContentStore();

  static const cacheKey = 'hotrest.site.published.v1';

  final KvStore _kv;
  final SiteRepository Function() _repository;
  final Duration timeout;

  final docs = ValueNotifier<Map<String, PublishedDoc>>(const {});

  bool _started = false;

  /// True once a fetch has completed (successfully or not).
  bool refreshed = false;

  void start() {
    if (_started) return;
    _started = true;
    docs.value = _readCache();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    try {
      final list = await _repository().fetchPublished().timeout(timeout);
      final map = {for (final d in list) d.key: d};
      docs.value = map;
      _writeCache(map);
    } catch (_) {
      // Keep the cache / defaults. Content must never be a reason for the site
      // not to load.
    } finally {
      refreshed = true;
    }
  }

  Map<String, PublishedDoc> _readCache() {
    try {
      final raw = _kv.read(cacheKey);
      if (raw == null) return const {};
      final list = jsonDecode(raw);
      if (list is! List) return const {};
      final out = <String, PublishedDoc>{};
      for (final item in list) {
        try {
          final d = PublishedDoc.fromJson(Map<String, dynamic>.from(item as Map));
          out[d.key] = d;
        } catch (_) {
          // One bad cached entry is dropped, not the rest.
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  void _writeCache(Map<String, PublishedDoc> map) {
    try {
      _kv.write(cacheKey, jsonEncode([for (final d in map.values) d.toJson()]));
    } catch (_) {}
  }

  /// Forget the cache (used after a publish in the same browser, so the admin
  /// does not see their own stale copy).
  void clearCache() => _kv.remove(cacheKey);
}
