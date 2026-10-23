import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cms/chrome/footer_content.dart';
import '../cms/chrome/header_content.dart';
import '../cms/data/site_providers.dart';
import '../cms/model/json_reader.dart';
import '../cms/model/site_document.dart';
import '../cms/model/site_theme.dart';
import '../cms/platform/open_external.dart';
import '../cms/platform/unload_guard.dart';
import 'field_env.dart';
import 'json_path.dart';
import 'media/media_library.dart';
import 'studio_controller.dart';
import 'studio_pages.dart';
import 'studio_providers.dart';
import 'studio_state.dart';
import 'studio_theme.dart';
import 'widgets/dialogs.dart';
import 'widgets/property_panel.dart';
import 'widgets/section_list.dart';
import 'widgets/site_preview.dart';

/// The website editor, shown as a tab of the superadmin console.
class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key});

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  // Captured now: a ref cannot be used after the widget is disposed, and the
  // last unsaved edit should be sent when the admin leaves the tab.
  late final StudioController _controller = ref.read(studioControllerProvider.notifier);

  /// Window width below which the two side panels become slide-overs.
  static const _wide = 1240.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureOpen());
  }

  @override
  void dispose() {
    // Sent after this frame: flush() updates the controller's state, and doing
    // that while this element is still being torn down notifies widgets that are
    // mid-unmount.
    Future.microtask(_controller.flush);
    setUnloadGuard(false);
    super.dispose();
  }

  void _ensureOpen() {
    if (!mounted) return;
    final key = ref.read(studioUiProvider).docKey;
    if (key != null && ref.read(studioControllerProvider).key != key) {
      _controller.open(key);
    }
  }

  void _go(StudioUi Function(StudioUi) f) {
    ref.read(studioUiProvider.notifier).update(f);
    _ensureOpen();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioControllerProvider);
    final ui = ref.watch(studioUiProvider);

    // Ask the browser to confirm closing the tab while there is anything unsaved.
    setUnloadGuard(state.status == SaveStatus.dirty ||
        state.status == SaveStatus.saving ||
        state.status == SaveStatus.error);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _controller.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _controller.flush,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _controller.flush,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: SC.bg,
          child: Column(
            children: [
              _TopBar(state: state, ui: ui, controller: _controller, go: _go),
              if (state.error != null) _Banner(state: state, controller: _controller),
              Expanded(
                child: ui.workspace == StudioWorkspace.media
                    ? Container(
                        color: Colors.white,
                        child: MediaLibrary(
                          repository: ref.watch(siteRepositoryProvider),
                          usageOf: _usageOf,
                        ),
                      )
                    : LayoutBuilder(builder: (context, box) => _body(state, ui, box.maxWidth >= _wide)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ──

  Widget _body(StudioState state, StudioUi ui, bool wide) {
    final showLeft = ui.workspace == StudioWorkspace.pages;
    final left = showLeft ? _leftPanel(state) : null;
    final right = _rightPanel(state, ui);
    final center = _preview(state, ui);

    if (wide) {
      return Row(
        children: [
          if (left != null) _Pane(width: 300, side: _Side.left, child: left),
          Expanded(child: Padding(padding: const EdgeInsets.all(14), child: center)),
          _Pane(width: 370, side: _Side.right, child: right),
        ],
      );
    }

    // Narrow: the preview keeps the space, and each panel slides over it.
    return Stack(
      children: [
        Positioned.fill(child: Padding(padding: const EdgeInsets.all(10), child: center)),
        Positioned(
          left: 10,
          top: 10,
          child: Row(
            children: [
              if (left != null)
                _FloatingToggle(
                  icon: Icons.view_list_rounded,
                  label: 'Sections',
                  onTap: () => _go((u) => u.copyWith(leftOpen: !u.leftOpen, rightOpen: false)),
                ),
            ],
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: _FloatingToggle(
            icon: Icons.tune_rounded,
            label: 'Properties',
            onTap: () => _go((u) => u.copyWith(rightOpen: !u.rightOpen, leftOpen: false)),
          ),
        ),
        if (left != null && ui.leftOpen)
          Positioned(left: 0, top: 0, bottom: 0, child: _Pane(width: 320, side: _Side.left, elevated: true, child: left)),
        if (ui.rightOpen)
          Positioned(right: 0, top: 0, bottom: 0, child: _Pane(width: 380, side: _Side.right, elevated: true, child: right)),
      ],
    );
  }

  List<Map<String, dynamic>> _sections(StudioState s) => s.doc['sections'] is List
      ? [for (final x in s.doc['sections'] as List) if (x is Map) Map<String, dynamic>.from(x)]
      : <Map<String, dynamic>>[];

  Widget _leftPanel(StudioState state) {
    return SectionList(
      sections: _sections(state),
      selectedId: state.selectedId,
      pageSettingsSelected: state.selectedId == kPageSettingsId,
      issues: state.issues,
      onSelect: (id) {
        _controller.select(id);
        _go((u) => u.copyWith(rightOpen: true, leftOpen: false));
      },
      onPageSettings: () {
        _controller.select(kPageSettingsId);
        _go((u) => u.copyWith(rightOpen: true, leftOpen: false, panelTab: PanelTab.content));
      },
      onToggle: _controller.setSectionEnabled,
      onDuplicate: _controller.duplicateSection,
      onDelete: (id) async {
        final ok = await confirm(
          context,
          title: 'Delete this section?',
          body: 'It is removed from your working copy. You can undo this, and nothing changes on '
              'the live site until you publish.',
          action: 'Delete',
          danger: true,
        );
        if (ok) _controller.removeSection(id);
      },
      onReorder: _controller.moveSection,
      onAdd: () async {
        final spec = await showAddSectionDialog(context);
        if (spec == null) return;
        _controller.addSection(
          {
            'id': spec.type,
            'type': spec.type,
            'content': deepCopy(spec.template),
          },
          afterId: state.selectedId == kPageSettingsId ? null : state.selectedId,
        );
        _go((u) => u.copyWith(panelTab: PanelTab.content));
      },
    );
  }

  Widget _rightPanel(StudioState state, StudioUi ui) {
    final anchors = <String>[
      for (final s in _sections(state))
        if (J.of(s).strOrNull('anchor') != null) J.of(s).str('anchor'),
    ];
    final env = FieldEnv(
      edit: _controller.edit,
      anchors: anchors,
      issues: state.issues,
      pickImage: (ctx) => showMediaPicker(ctx, ref.read(siteRepositoryProvider), usageOf: _usageOf),
    );
    return PropertyPanel(
      state: state,
      ui: ui,
      env: env,
      onTab: (t) => _go((u) => u.copyWith(panelTab: t)),
    );
  }

  List<String> _usageOf(String url) {
    final docs = <String, Object?>{
      for (final e in ref.read(publishedDocsProvider).entries) e.key: e.value.content,
      ref.read(studioControllerProvider).key: ref.read(studioControllerProvider).doc,
    };
    return findUsage(url, docs);
  }

  Widget _preview(StudioState state, StudioUi ui) {
    if (state.loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));

    final publishedTheme = ref.watch(siteThemeProvider);
    HeaderContent header = HeaderContent.fromJson(J.of(ref.watch(siteRawProvider('global:header'))));
    FooterContent footer = FooterContent.fromJson(J.of(ref.watch(siteRawProvider('global:footer'))));

    switch (ui.workspace) {
      case StudioWorkspace.pages:
        // The landing header and footer belong to the home page only; the help,
        // legal and sign-in pages have their own chrome.
        final home = state.key == 'page:home';
        return SitePreview(
          doc: previewDocument(state.doc, state.key),
          device: ui.device,
          theme: publishedTheme,
          header: home ? header : null,
          footer: home ? footer : null,
          selectedId: state.selectedId == kPageSettingsId ? null : state.selectedId,
          onSelect: (id) {
            _controller.select(id);
            _go((u) => u.copyWith(rightOpen: true, leftOpen: false));
          },
          onSelectChrome: () => _go((u) => u.copyWith(workspace: StudioWorkspace.navigation)),
        );
      case StudioWorkspace.navigation:
        if (ui.navDoc == 'global:header') {
          header = HeaderContent.fromJson(J.of(state.doc));
        } else {
          footer = FooterContent.fromJson(J.of(state.doc));
        }
        return SitePreview(
          doc: ref.watch(siteDocumentProvider('page:home')),
          device: ui.device,
          theme: publishedTheme,
          header: header,
          footer: footer,
        );
      case StudioWorkspace.theme:
        final j = J.of(state.doc);
        return SitePreview(
          doc: ref.watch(siteDocumentProvider('page:home')),
          device: ui.device,
          theme: SiteTheme.fromJson(j.obj('typography'), j.obj('layout')),
          header: header,
          footer: footer,
        );
      case StudioWorkspace.settings:
        return SitePreview(
          doc: ref.watch(siteDocumentProvider('page:home')),
          device: ui.device,
          theme: publishedTheme,
          header: header,
          footer: footer,
        );
      case StudioWorkspace.media:
        return const SizedBox.shrink();
    }
  }
}

/// Where a picture is used, by document key, for the delete warning.
List<String> findUsage(String url, Map<String, Object?> docs) {
  final hits = <String>[];
  bool contains(Object? v) => switch (v) {
        String s => s == url,
        Map m => m.values.any(contains),
        List l => l.any(contains),
        _ => false,
      };
  docs.forEach((k, v) {
    if (contains(v)) hits.add(k);
  });
  return hits;
}

enum _Side { left, right }

class _Pane extends StatelessWidget {
  const _Pane({required this.width, required this.child, required this.side, this.elevated = false});

  final double width;
  final Widget child;
  final _Side side;
  final bool elevated;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(
          color: SC.panel,
          border: Border(
            left: side == _Side.right ? const BorderSide(color: SC.border) : BorderSide.none,
            right: side == _Side.left ? const BorderSide(color: SC.border) : BorderSide.none,
          ),
          boxShadow: elevated ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24)] : null,
        ),
        child: child,
      );
}

class _FloatingToggle extends StatelessWidget {
  const _FloatingToggle({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: SC.accent),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: SC.text)),
              ],
            ),
          ),
        ),
      );
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.state, required this.ui, required this.controller, required this.go});

  final StudioState state;
  final StudioUi ui;
  final StudioController controller;
  final void Function(StudioUi Function(StudioUi)) go;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = studioPageFor(ui.pageKey);
    final isDoc = ui.workspace != StudioWorkspace.media;
    final dirty = controller.differsFromPublished;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: SC.border))),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        spacing: 10,
        children: [
          const Icon(Icons.web_rounded, size: 20, color: SC.accent),
          const Text('Website', style: SC.title),
          const SizedBox(width: 6),
          SegmentedButton<StudioWorkspace>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: StudioWorkspace.pages, label: Text('Pages'), icon: Icon(Icons.article_outlined, size: 16)),
              ButtonSegment(value: StudioWorkspace.navigation, label: Text('Header & footer'), icon: Icon(Icons.menu_open_rounded, size: 16)),
              ButtonSegment(value: StudioWorkspace.theme, label: Text('Theme'), icon: Icon(Icons.palette_outlined, size: 16)),
              ButtonSegment(value: StudioWorkspace.settings, label: Text('Settings'), icon: Icon(Icons.settings_outlined, size: 16)),
              ButtonSegment(value: StudioWorkspace.media, label: Text('Media'), icon: Icon(Icons.photo_library_outlined, size: 16)),
            ],
            selected: {ui.workspace},
            onSelectionChanged: (s) => go((u) => u.copyWith(workspace: s.first, leftOpen: false, rightOpen: false)),
          ),
          if (ui.workspace == StudioWorkspace.pages && kStudioPages.length > 1)
            DropdownButton<String>(
              value: ui.pageKey,
              underline: const SizedBox.shrink(),
              style: SC.body.copyWith(fontWeight: FontWeight.w600),
              items: [for (final p in kStudioPages) DropdownMenuItem(value: p.key, child: Text(p.label))],
              onChanged: (k) => k == null ? null : go((u) => u.copyWith(pageKey: k)),
            )
          else if (ui.workspace == StudioWorkspace.pages && page != null)
            Chip2(page.label, color: SC.muted),
          if (ui.workspace == StudioWorkspace.navigation)
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'global:header', label: Text('Header')),
                ButtonSegment(value: 'global:footer', label: Text('Footer')),
              ],
              selected: {ui.navDoc},
              onSelectionChanged: (s) => go((u) => u.copyWith(navDoc: s.first)),
            ),
          if (isDoc) ...[
            SegmentedButton<Device>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: Device.desktop, icon: Icon(Icons.desktop_windows_outlined, size: 16), tooltip: 'Desktop preview'),
                ButtonSegment(value: Device.tablet, icon: Icon(Icons.tablet_mac_outlined, size: 16), tooltip: 'Tablet preview'),
                ButtonSegment(value: Device.mobile, icon: Icon(Icons.phone_iphone_rounded, size: 16), tooltip: 'Phone preview'),
              ],
              selected: {ui.device},
              onSelectionChanged: (s) => go((u) => u.copyWith(device: s.first)),
            ),
            IconButton(
              tooltip: 'Undo (Ctrl/⌘ Z)',
              onPressed: state.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 20),
            ),
            IconButton(
              tooltip: 'Redo (Ctrl/⌘ Shift Z)',
              onPressed: state.canRedo ? controller.redo : null,
              icon: const Icon(Icons.redo_rounded, size: 20),
            ),
            _StatusChip(state: state, dirty: dirty),
            if (state.errors.isNotEmpty)
              Tooltip(
                message: state.errors.take(6).map((e) => e.message).join('\n'),
                child: Chip2('${state.errors.length} to fix', color: SC.danger, icon: Icons.error_outline_rounded),
              ),
            if (state.warnings.isNotEmpty)
              Tooltip(
                message: state.warnings.take(6).map((e) => e.message).join('\n'),
                child: Chip2('${state.warnings.length} warning${state.warnings.length == 1 ? '' : 's'}',
                    color: SC.warn, icon: Icons.warning_amber_rounded),
              ),
            const SizedBox(width: 6),
            if (ui.workspace == StudioWorkspace.pages && page != null)
              TextButton.icon(
                onPressed: () => openExternal(page.route),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('View live'),
              ),
            TextButton.icon(
              onPressed: state.loading || state.key.isEmpty
                  ? null
                  : () => showRevisionsDialog(
                        context,
                        pageLabel: page?.label ?? state.key,
                        load: () => ref.read(siteRepositoryProvider).listRevisions(state.key),
                        onRestore: controller.restoreRevision,
                      ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('History'),
            ),
            TextButton(
              onPressed: state.source == DocSource.draft || dirty
                  ? () async {
                      final ok = await confirm(
                        context,
                        title: 'Discard your draft?',
                        body: 'Your unpublished changes to this page are thrown away and the editor '
                            'goes back to the live version. This cannot be undone.',
                        action: 'Discard',
                        danger: true,
                      );
                      if (ok) await controller.discard();
                    }
                  : null,
              child: const Text('Discard draft'),
            ),
            FilledButton.icon(
              onPressed: state.loading || state.publishing || !dirty ? null : () => _publish(context),
              style: FilledButton.styleFrom(backgroundColor: SC.accent),
              icon: state.publishing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch_rounded, size: 17),
              label: const Text('Publish'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _publish(BuildContext context) async {
    if (state.errors.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Fix these first'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [for (final e in state.errors) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• ${e.message}', style: SC.body))],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      return;
    }
    final page = studioPageFor(state.key);
    final note = await showPublishDialog(
      context,
      pageLabel: page?.label ?? state.key.replaceFirst(RegExp(r'^(page|global):'), ''),
      published: state.published,
      draft: state.doc,
      issues: state.issues,
      noteRequired: page?.legal ?? false,
    );
    if (note == null) return;
    final ok = await controller.publish(note);
    if (ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Published. The live site now shows this version.')));
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, required this.dirty});

  final StudioState state;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final (text, color, icon) = switch (state.status) {
      SaveStatus.saving => ('Saving…', SC.muted, Icons.sync_rounded),
      SaveStatus.dirty => ('Unsaved changes', SC.warn, Icons.edit_rounded),
      SaveStatus.error => ('Not saved', SC.danger, Icons.cloud_off_rounded),
      SaveStatus.conflict => ('Edited elsewhere', SC.danger, Icons.sync_problem_rounded),
      SaveStatus.saved => dirty
          ? ('Draft saved · not published', SC.warn, Icons.cloud_done_outlined)
          : ('Matches the live site', SC.ok, Icons.check_circle_outline_rounded),
    };
    return Chip2(text, color: color, icon: icon);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final conflict = state.status == SaveStatus.conflict;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: conflict ? SC.dangerBg : SC.warnBg,
      child: Row(
        children: [
          Icon(conflict ? Icons.sync_problem_rounded : Icons.info_outline_rounded, size: 18, color: conflict ? SC.danger : SC.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              conflict
                  ? 'This page was saved from another window or by another admin. Your edits here are not '
                      'being saved. Reload to see the latest, then redo your changes.'
                  : state.error!,
              style: SC.body,
            ),
          ),
          if (conflict) TextButton(onPressed: controller.reloadFromServer, child: const Text('Reload')),
        ],
      ),
    );
  }
}
