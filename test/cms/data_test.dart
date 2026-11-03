import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/data/memory_site_repository.dart';
import 'package:hotel_checkin/web/cms/data/site_content_store.dart';
import 'package:hotel_checkin/web/cms/data/site_providers.dart';
import 'package:hotel_checkin/web/cms/data/site_repository.dart';
import 'package:hotel_checkin/web/cms/defaults/site_defaults.dart';
import 'package:hotel_checkin/web/cms/platform/kv_store.dart';

PublishedDoc _doc(String key, Map<String, dynamic> content, [int v = 1]) =>
    PublishedDoc(key: key, content: content, version: v);

Map<String, dynamic> _home(String title) => {
      'schema': 1,
      'sections': [
        {
          'id': 'faq',
          'type': 'faq',
          'content': {'title': title},
        },
      ],
    };

void main() {
  final kv = KvStore();
  setUp(() => kv.remove(SiteContentStore.cacheKey));

  group('SiteContentStore', () {
    test('publishes the cache immediately, then swaps in the fetch', () async {
      kv.write(SiteContentStore.cacheKey, jsonEncode([_doc('page:home', _home('cached')).toJson()]));
      final gate = Completer<void>();
      final repo = _SlowRepo(gate.future, [_doc('page:home', _home('fresh'), 2)]);
      final store = SiteContentStore(kv: kv, repository: () => repo);

      store.start();
      expect(store.docs.value['page:home']!.content['sections'][0]['content']['title'], 'cached');

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(store.docs.value['page:home']!.version, 2);
      expect(store.refreshed, isTrue);
    });

    test('a failed fetch keeps what it had', () async {
      kv.write(SiteContentStore.cacheKey, jsonEncode([_doc('page:home', _home('cached')).toJson()]));
      final repo = MemorySiteRepository()..failWith = Exception('table does not exist');
      final store = SiteContentStore(kv: kv, repository: () => repo);

      store.start();
      await store.refresh();

      expect(store.docs.value['page:home']!.content['sections'][0]['content']['title'], 'cached');
      expect(store.refreshed, isTrue);
    });

    test('a hung fetch times out instead of waiting forever', () async {
      final repo = _SlowRepo(Completer<void>().future, const []); // never completes
      final store = SiteContentStore(
          kv: kv, repository: () => repo, timeout: const Duration(milliseconds: 20));
      await store.refresh();
      expect(store.refreshed, isTrue);
      expect(store.docs.value, isEmpty);
    });

    test('a corrupt cache is ignored, not fatal', () {
      kv.write(SiteContentStore.cacheKey, '{not json');
      final store = SiteContentStore(kv: kv, repository: MemorySiteRepository.new);
      store.start();
      expect(store.docs.value, isEmpty);
    });

    test('one bad cached entry does not discard the others', () {
      kv.write(
        SiteContentStore.cacheKey,
        jsonEncode([
          {'nonsense': true},
          _doc('page:help', {'sections': []}).toJson(),
        ]),
      );
      final store = SiteContentStore(kv: kv, repository: MemorySiteRepository.new);
      store.start();
      expect(store.docs.value.keys, ['page:help']);
    });

    test('a successful fetch refreshes the cache for next time', () async {
      final repo = MemorySiteRepository(published: [_doc('page:home', _home('live'))]);
      final store = SiteContentStore(kv: kv, repository: () => repo);
      await store.refresh();
      final again = SiteContentStore(kv: kv, repository: MemorySiteRepository.new)..start();
      expect(again.docs.value.containsKey('page:home'), isTrue);
    });
  });

  group('providers', () {
    ProviderContainer container(Map<String, PublishedDoc> docs) => ProviderContainer(overrides: [
          publishedDocsProvider.overrideWith((ref) => _Fixed(docs)),
        ]);

    test('no published document: the bundled default', () {
      final c = container({});
      addTearDown(c.dispose);
      final doc = c.read(siteDocumentProvider('page:home'));
      expect(doc.sections.map((s) => s.type), contains('hero'));
      expect(doc.sections.length, siteDefaultDocument('page:home').sections.length);
    });

    test('a published document replaces the default', () {
      final c = container({'page:home': _doc('page:home', _home('Published'))});
      addTearDown(c.dispose);
      final doc = c.read(siteDocumentProvider('page:home'));
      expect(doc.sections.single.content.str('title'), 'Published');
    });

    test('a published document with only invalid sections falls back to the default', () {
      final c = container({
        'page:home': _doc('page:home', {
          'sections': [
            {'nope': 1},
            {'id': '', 'type': ''},
          ],
        }),
      });
      addTearDown(c.dispose);
      expect(c.read(siteDocumentProvider('page:home')).sections.length,
          siteDefaultDocument('page:home').sections.length);
    });

    test('an intentionally empty page stays empty', () {
      final c = container({'page:home': _doc('page:home', {'schema': 1, 'sections': []})});
      addTearDown(c.dispose);
      expect(c.read(siteDocumentProvider('page:home')).sections, isEmpty);
    });

    test('defaults handed out are copies', () {
      final a = siteDefaultJson('page:home');
      (a['sections'] as List).clear();
      expect((siteDefaultJson('page:home')['sections'] as List), isNotEmpty);
    });
  });

  group('MemorySiteRepository follows the SQL rules', () {
    test('save → publish bumps the version and records a revision', () async {
      final r = MemorySiteRepository();
      expect(await r.saveDraft('page:home', _home('A'), 0), 1);
      expect(await r.publish('page:home', 'first'), 1);
      expect(await r.saveDraft('page:home', _home('B'), 1), 2);
      expect(await r.publish('page:home', 'second'), 2);
      final revs = await r.listRevisions('page:home');
      expect(revs.map((e) => e.rev), [2, 1]);
      expect(revs.first.note, 'second');
      expect((await r.fetchPublished()).single.version, 2);
    });

    test('a stale save is a conflict, not an overwrite', () async {
      final r = MemorySiteRepository();
      await r.saveDraft('page:home', _home('A'), 0);
      await r.saveDraft('page:home', _home('B'), 1);
      expect(() => r.saveDraft('page:home', _home('C'), 1), throwsA(isA<SiteConflict>()));
      expect((await r.loadDraft('page:home'))!.content['sections'][0]['content']['title'], 'B');
    });

    test('creating over an existing draft with expected 0 conflicts', () async {
      final r = MemorySiteRepository();
      await r.saveDraft('page:home', _home('A'), 0);
      expect(() => r.saveDraft('page:home', _home('B'), 0), throwsA(isA<SiteConflict>()));
    });

    test('restore writes the draft, not the live document', () async {
      final r = MemorySiteRepository();
      await r.saveDraft('page:home', _home('Old'), 0);
      await r.publish('page:home', 'v1');
      await r.saveDraft('page:home', _home('New'), 1);
      await r.publish('page:home', 'v2');

      await r.restoreRevision('page:home', 1);

      final live = (await r.fetchPublished()).single;
      expect(live.content['sections'][0]['content']['title'], 'New', reason: 'live is untouched');
      final draft = (await r.loadDraft('page:home'))!;
      expect(draft.content['sections'][0]['content']['title'], 'Old');
    });

    test('discard removes the working copy only', () async {
      final r = MemorySiteRepository();
      await r.saveDraft('page:home', _home('A'), 0);
      await r.publish('page:home', '');
      await r.discardDraft('page:home');
      expect(await r.loadDraft('page:home'), isNull);
      expect((await r.fetchPublished()), hasLength(1));
    });

    test('publishing with no draft fails', () async {
      expect(() => MemorySiteRepository().publish('page:home', ''), throwsStateError);
    });

    test('stored content is a copy: later edits do not leak in', () async {
      final r = MemorySiteRepository();
      final c = _home('A');
      await r.saveDraft('page:home', c, 0);
      (c['sections'] as List).clear();
      expect(((await r.loadDraft('page:home'))!.content['sections'] as List), isNotEmpty);
    });

    test('media: upload, alt, delete', () async {
      final r = MemorySiteRepository();
      final m = await r.uploadMedia(
          bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/png', originalName: 'a.png');
      await r.setMediaAlt(m.id, 'A picture');
      expect((await r.listMedia()).single.alt, 'A picture');
      await r.deleteMedia(m.id);
      expect(await r.listMedia(), isEmpty);
    });
  });
}

class _Fixed extends PublishedDocs {
  _Fixed(Map<String, PublishedDoc> docs) : super(_FixedStore(docs));
}

class _FixedStore extends SiteContentStore {
  _FixedStore(Map<String, PublishedDoc> docs) : super(repository: MemorySiteRepository.new) {
    this.docs.value = docs;
  }
}

class _SlowRepo extends MemorySiteRepository {
  _SlowRepo(this.gate, this.docs);

  final Future<void> gate;
  final List<PublishedDoc> docs;

  @override
  Future<List<PublishedDoc>> fetchPublished() async {
    await gate;
    return docs;
  }
}
