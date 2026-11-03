import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../defaults/site_defaults.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../model/site_theme.dart';
import 'site_content_store.dart';
import 'site_repository.dart';
import 'supabase_site_repository.dart';

final siteRepositoryProvider = Provider<SiteRepository>((_) => SupabaseSiteRepository());

/// Mirrors the store's notifier into Riverpod so widgets rebuild when fresh
/// content arrives. Override this in tests to supply published documents.
class PublishedDocs extends StateNotifier<Map<String, PublishedDoc>> {
  PublishedDocs(SiteContentStore store) : _store = store, super(store.docs.value) {
    store.docs.addListener(_sync);
  }

  final SiteContentStore _store;

  void _sync() => state = _store.docs.value;

  @override
  void dispose() {
    _store.docs.removeListener(_sync);
    super.dispose();
  }
}

final publishedDocsProvider = StateNotifierProvider<PublishedDocs, Map<String, PublishedDoc>>(
  (ref) => PublishedDocs(SiteContentStore.instance),
);

/// The raw JSON for [key]: published if there is one, else the bundled default.
final siteRawProvider = Provider.family<Map<String, dynamic>, String>((ref, key) {
  final published = ref.watch(publishedDocsProvider.select((m) => m[key]));
  return published?.content ?? siteDefaultJson(key);
});

/// A page document, parsed. Falls back to the bundled default when the published
/// one parses to nothing at all (every section invalid): an empty home page is
/// never the intended result of an edit, and a blank front door is the worst
/// failure the site can have.
final siteDocumentProvider = Provider.family<SiteDocument, String>((ref, key) {
  final raw = ref.watch(siteRawProvider(key));
  final doc = SiteDocument.fromJson(raw);
  final hadSections = raw['sections'] is List && (raw['sections'] as List).isNotEmpty;
  if (doc.sections.isEmpty && hadSections) return siteDefaultDocument(key);
  return doc;
});

/// The global theme (`global:theme`) as a cascade level.
final siteThemeProvider = Provider<SiteTheme>((ref) {
  final j = J.of(ref.watch(siteRawProvider('global:theme')));
  return SiteTheme.fromJson(j.obj('typography'), j.obj('layout'));
});
