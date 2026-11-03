import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/web/cms/data/memory_site_repository.dart';
import 'package:hotel_checkin/web/cms/data/site_repository.dart';
import 'package:hotel_checkin/web/studio/json_path.dart';
import 'package:hotel_checkin/web/studio/studio_controller.dart';
import 'package:hotel_checkin/web/studio/studio_state.dart';

Map<String, dynamic> _defaults(String key) => {
      'schema': 1,
      'sections': [
        {'id': 'a', 'type': 'faq', 'content': {'title': 'A'}},
        {'id': 'b', 'type': 'faq', 'content': {'title': 'B'}},
        {'id': 'c', 'type': 'faq', 'content': {'title': 'C'}},
      ],
    };

StudioController _make(MemorySiteRepository repo, {Validator? validator, List<int>? published}) =>
    StudioController(
      repository: repo,
      defaults: _defaults,
      validator: validator,
      autosaveDelay: Duration.zero,
      onPublished: published == null ? null : () => published.add(1),
    );

List<String> _ids(StudioController c) =>
    [for (final s in c.state.doc['sections'] as List) (s as Map)['id'] as String];

void main() {
  group('json path', () {
    test('getAt walks maps and lists and never throws', () {
      final d = {'a': [{'b': 1}]};
      expect(getAt(d, ['a', 0, 'b']), 1);
      expect(getAt(d, ['a', 5, 'b']), isNull);
      expect(getAt(d, ['x', 'y']), isNull);
      expect(getAt(d, ['a', 'b']), isNull);
    });

    test('setAt creates intermediate maps', () {
      final d = <String, dynamic>{};
      setAt(d, ['a', 'b', 'c'], 1);
      expect(d, {'a': {'b': {'c': 1}}});
    });

    test('setAt with null removes a key', () {
      final d = <String, dynamic>{'a': {'b': 1, 'c': 2}};
      setAt(d, ['a', 'b'], null);
      expect(d['a'], {'c': 2});
    });

    test('setAt into a missing list index throws instead of corrupting', () {
      final d = <String, dynamic>{'a': <dynamic>[]};
      expect(() => setAt(d, ['a', 3, 'x'], 1), throwsArgumentError);
    });

    test('deepCopy is independent', () {
      final a = {'x': [1, {'y': 2}]};
      final b = deepCopy(a);
      ((b['x'] as List)[1] as Map)['y'] = 9;
      expect(((a['x'] as List)[1] as Map)['y'], 2);
    });
  });

  group('loading', () {
    test('nothing published, no draft: opens on the bundled defaults', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      expect(c.state.source, DocSource.defaults);
      expect(_ids(c), ['a', 'b', 'c']);
      expect(c.state.status, SaveStatus.saved);
      expect(c.state.selectedId, 'a');
      expect(c.differsFromPublished, isFalse);
    });

    test('a draft wins over the published document', () async {
      final repo = MemorySiteRepository(published: [
        PublishedDoc(key: 'page:home', version: 3, content: {'sections': [{'id': 'p', 'type': 'faq'}]}),
      ]);
      await repo.saveDraft('page:home', {'sections': [{'id': 'd', 'type': 'faq'}]}, 0);
      final c = _make(repo);
      await c.open('page:home');
      expect(c.state.source, DocSource.draft);
      expect(_ids(c), ['d']);
      expect(c.state.publishedVersion, 3);
      expect(c.differsFromPublished, isTrue);
    });

    test('a backend failure still opens the editor, and says so', () async {
      final repo = MemorySiteRepository()
        ..failWith = Exception('relation "site_drafts" does not exist (42P01)');
      final c = _make(repo);
      await c.open('page:home');
      expect(c.state.loading, isFalse);
      expect(_ids(c), ['a', 'b', 'c'], reason: 'defaults, so there is something to look at');
      expect(c.state.error, contains('migration'));
      expect(c.state.status, SaveStatus.error);
    });

    test('a permission failure is explained', () async {
      final repo = MemorySiteRepository()..failWith = Exception('Only a superadmin (42501)');
      final c = _make(repo);
      await c.open('page:home');
      expect(c.state.error, contains('superadmin'));
    });
  });

  group('editing and undo', () {
    test('an edit marks dirty and changes the working copy only', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'New');
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'New');
      expect(getAt(c.state.published, ['sections', 0, 'content', 'title']), 'A');
      expect(c.state.status, SaveStatus.dirty);
      expect(c.differsFromPublished, isTrue);
    });

    test('undo and redo restore exact states', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.moveSection(0, 2); // a to the end
      expect(_ids(c), ['b', 'c', 'a']);
      expect(c.state.canUndo, isTrue);
      c.undo();
      expect(_ids(c), ['a', 'b', 'c']);
      expect(c.state.canRedo, isTrue);
      c.redo();
      expect(_ids(c), ['b', 'c', 'a']);
      expect(c.state.canRedo, isFalse);
    });

    test('a new edit clears the redo history', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.setSectionEnabled('a', false);
      c.undo();
      c.setSectionEnabled('b', false);
      expect(c.state.canRedo, isFalse);
    });

    test('typing in one field is one undo step', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      for (final t in ['N', 'Ne', 'New', 'New t', 'New ti']) {
        c.edit(['sections', 0, 'content', 'title'], t);
      }
      c.undo();
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'A');
      expect(c.state.canUndo, isFalse);
    });

    test('editing different fields makes separate undo steps', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'X');
      c.edit(['sections', 1, 'content', 'title'], 'Y');
      c.undo();
      expect(getAt(c.state.doc, ['sections', 1, 'content', 'title']), 'B');
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'X');
    });

    test('setting a value to what it already is is not an edit', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'A');
      expect(c.state.status, SaveStatus.saved);
      expect(c.state.canUndo, isFalse);
    });

    test('null removes the key (reset to inherited)', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.edit(['sections', 0, 'typography', 'heading', 'desktop'], 64);
      c.edit(['sections', 0, 'typography', 'heading', 'desktop'], null);
      expect(getAt(c.state.doc, ['sections', 0, 'typography', 'heading', 'desktop']), isNull);
    });

    test('validation runs on every edit', () async {
      final c = _make(MemorySiteRepository(),
          validator: (key, doc) => [
                if (getAt(doc, ['sections', 0, 'content', 'title']) == '')
                  const ValidationIssue(severity: IssueSeverity.error, message: 'Title is required'),
              ]);
      await c.open('page:home');
      expect(c.state.errors, isEmpty);
      c.edit(['sections', 0, 'content', 'title'], '');
      expect(c.state.errors.single.message, 'Title is required');
    });
  });

  group('sections', () {
    test('add inserts after the given section with a unique id and selects it', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      final id = c.addSection({'id': 'a', 'type': 'faq', 'content': {}}, afterId: 'a');
      expect(id, 'a-2');
      expect(_ids(c), ['a', 'a-2', 'b', 'c']);
      expect(c.state.selectedId, 'a-2');
    });

    test('add with no anchor goes to the end', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.addSection({'type': 'spacer', 'content': {}});
      expect(_ids(c).last, 'spacer');
    });

    test('duplicate copies content, new id, drops the anchor', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.edit(['sections', 1, 'anchor'], 'pricing');
      final id = c.duplicateSection('b')!;
      expect(id, 'b-2');
      final copy = c.sectionById(id)!;
      expect(copy['anchor'], isNull, reason: 'two sections must not answer one link');
      expect(getAt(copy, ['content', 'title']), 'B');
      expect(c.sectionById('b')!['anchor'], 'pricing');
    });

    test('remove selects a neighbour', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.select('b');
      c.removeSection('b');
      expect(_ids(c), ['a', 'c']);
      expect(c.state.selectedId, 'a');
    });

    test('removing the first selects the next', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.select('a');
      c.removeSection('a');
      expect(c.state.selectedId, 'b');
    });

    test('removing the last remaining section leaves nothing selected', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      for (final id in ['a', 'b', 'c']) {
        c.removeSection(id);
      }
      expect(_ids(c), isEmpty);
      expect(c.state.selectedId, isNull);
    });

    test('moveSection puts the section at the final index', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.moveSection(0, 1); // a below b
      expect(_ids(c), ['b', 'a', 'c']);
      c.moveSection(2, 0);
      expect(_ids(c), ['c', 'b', 'a']);
      c.moveSection(1, 1);
      expect(_ids(c), ['c', 'b', 'a'], reason: 'no-op');
      c.moveSection(0, 99);
      expect(_ids(c), ['b', 'a', 'c'], reason: 'clamped to the end');
    });

    test('disable is stored only when off', () async {
      final c = _make(MemorySiteRepository());
      await c.open('page:home');
      c.setSectionEnabled('a', false);
      expect(c.sectionById('a')!['enabled'], false);
      c.setSectionEnabled('a', true);
      expect(c.sectionById('a')!.containsKey('enabled'), isFalse);
    });
  });

  group('saving and publishing', () {
    test('flush saves the draft and advances the version', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'Saved');
      await c.flush();
      expect(c.state.status, SaveStatus.saved);
      expect(c.state.draftVersion, 1);
      expect(c.state.source, DocSource.draft);
      expect((await repo.loadDraft('page:home'))!.content['sections'][0]['content']['title'], 'Saved');
    });

    test('nothing to save: flush makes no call', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      repo.log.clear();
      await c.flush();
      expect(repo.log, isEmpty);
    });

    test('publish makes it live and tells the site to refresh', () async {
      final repo = MemorySiteRepository();
      final pubs = <int>[];
      final c = _make(repo, published: pubs);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'Live');
      expect(await c.publish('first publish'), isTrue);
      expect(pubs, [1]);
      expect(c.state.publishedVersion, 1);
      expect(c.differsFromPublished, isFalse);
      final live = (await repo.fetchPublished()).single;
      expect(live.content['sections'][0]['content']['title'], 'Live');
      expect((await repo.listRevisions('page:home')).single.note, 'first publish');
    });

    test('validation errors block publishing', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo,
          validator: (_, __) =>
              [const ValidationIssue(severity: IssueSeverity.error, message: 'bad')]);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'x');
      expect(await c.publish(''), isFalse);
      expect(c.state.error, contains('error'));
      expect(await repo.fetchPublished(), isEmpty);
    });

    test('warnings do not block publishing', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo,
          validator: (_, __) =>
              [const ValidationIssue(severity: IssueSeverity.warning, message: 'meh')]);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'x');
      expect(await c.publish(''), isTrue);
    });

    test('a conflict stops autosave and keeps local edits', () async {
      final repo = MemorySiteRepository();
      final a = _make(repo);
      final b = _make(repo);
      await a.open('page:home');
      await b.open('page:home');
      a.edit(['sections', 0, 'content', 'title'], 'From A');
      await a.flush();
      b.edit(['sections', 0, 'content', 'title'], 'From B');
      await b.flush();
      expect(b.state.status, SaveStatus.conflict);
      expect(getAt(b.state.doc, ['sections', 0, 'content', 'title']), 'From B');
      expect((await repo.loadDraft('page:home'))!.content['sections'][0]['content']['title'], 'From A');

      await b.reloadFromServer();
      expect(getAt(b.state.doc, ['sections', 0, 'content', 'title']), 'From A');
      expect(b.state.status, SaveStatus.saved);
    });

    test('a failed save reports the error and keeps the edit', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'Kept');
      repo.failWith = Exception('network down');
      await c.flush();
      expect(c.state.status, SaveStatus.error);
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'Kept');
      repo.failWith = null;
      c.edit(['sections', 0, 'content', 'title'], 'Kept!'); // next edit retries
      await c.flush();
      expect(c.state.status, SaveStatus.saved);
    });

    test('discard returns to the published document', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'One');
      await c.publish('v1');
      c.edit(['sections', 0, 'content', 'title'], 'Two');
      await c.flush();
      await c.discard();
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'One');
      expect(c.state.source, DocSource.published);
    });

    test('restore loads the old revision into the draft, not live', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'One');
      await c.publish('v1');
      c.edit(['sections', 0, 'content', 'title'], 'Two');
      await c.publish('v2');
      await c.restoreRevision(1);
      expect(getAt(c.state.doc, ['sections', 0, 'content', 'title']), 'One');
      expect(c.differsFromPublished, isTrue);
      expect((await repo.fetchPublished()).single.content['sections'][0]['content']['title'], 'Two');
    });

    test('switching pages saves the one being left', () async {
      final repo = MemorySiteRepository();
      final c = _make(repo);
      await c.open('page:home');
      c.edit(['sections', 0, 'content', 'title'], 'Unsaved');
      await c.open('page:help');
      expect((await repo.loadDraft('page:home'))!.content['sections'][0]['content']['title'], 'Unsaved');
    });
  });
}
