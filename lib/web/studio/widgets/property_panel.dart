import 'package:flutter/material.dart';

import '../../cms/model/json_reader.dart';
import '../field_env.dart';
import '../specs/chrome_specs.dart';
import '../specs/section_specs.dart';
import '../studio_pages.dart';
import '../studio_providers.dart';
import '../studio_state.dart';
import '../studio_theme.dart';
import 'field_editors.dart';

/// The right-hand panel: the fields for whatever is selected, grouped into tabs.
class PropertyPanel extends StatelessWidget {
  const PropertyPanel({
    super.key,
    required this.state,
    required this.ui,
    required this.env,
    required this.onTab,
  });

  final StudioState state;
  final StudioUi ui;
  final FieldEnv env;
  final ValueChanged<PanelTab> onTab;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return switch (ui.workspace) {
      StudioWorkspace.pages => _forPages(context),
      StudioWorkspace.navigation => _Scroll(
          title: ui.navDoc == 'global:header' ? 'Header' : 'Footer',
          subtitle: ui.navDoc == 'global:header'
              ? 'The top bar on every public page, and the phone menu.'
              : 'The footer on the landing page.',
          issues: const [],
          child: FieldForm(
            fields: ui.navDoc == 'global:header' ? kHeaderFields : kFooterFields,
            values: state.doc,
            basePath: const [],
            env: env,
          ),
        ),
      StudioWorkspace.theme => _themeTabs(),
      StudioWorkspace.settings => _Scroll(
          title: 'Site settings',
          subtitle: 'Contact details and the chat button, used across the site.',
          issues: state.issues,
          child: FieldForm(fields: kSiteFields, values: state.doc, basePath: const [], env: env),
        ),
      StudioWorkspace.media => const SizedBox.shrink(),
    };
  }

  // ── Pages ──

  Widget _forPages(BuildContext context) {
    final id = state.selectedId;
    if (id == kPageSettingsId) return _pageSettings();

    final sections = state.doc['sections'] is List ? state.doc['sections'] as List : const [];
    final i = sections.indexWhere((s) => s is Map && s['id'] == id);
    if (id == null || i < 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Select a section in the list, or click one in the preview, to edit it.',
              textAlign: TextAlign.center, style: SC.small),
        ),
      );
    }

    final node = Map<String, dynamic>.from(sections[i] as Map);
    final type = node['type'] as String? ?? '';
    final spec = kSectionSpecByType[type];
    final mine = state.issues.where((x) => x.sectionId == id).toList();

    if (spec == null) {
      return _Scroll(
        title: 'Unknown section',
        subtitle: 'Type "$type"',
        issues: mine,
        child: const Text(
          'This section was made by a newer version of the editor, or by hand. The site skips it. '
          'You can hide or delete it from the list.',
          style: SC.small,
        ),
      );
    }

    final tab = _tab(ui.panelTab, const [
      PanelTab.content,
      PanelTab.layout,
      PanelTab.style,
      PanelTab.typography,
      PanelTab.visibility,
    ]);
    final base = <Object>['sections', i];

    // Comparison cells are one per column; the editor needs to know how many.
    var e = env;
    if (type == 'comparison') {
      final cols = J.of(node['content']).list('columns', (c) => c.str('short').isNotEmpty ? c.str('short') : c.str('name'));
      e = env.copyWith(columnCount: cols.length, columnNames: cols);
    }

    final (fields, values, path, hint) = switch (tab) {
      PanelTab.content => (spec.fields, _map(node['content']), [...base, 'content'], null),
      PanelTab.layout => (kLayoutFields, _map(node['layout']), [...base, 'layout'], null),
      PanelTab.style => (kStyleFields, _map(node['style']), [...base, 'style'], null),
      PanelTab.typography => (
          kTypographyFields,
          _map(node['typography']),
          [...base, 'typography'],
          'Anything left empty inherits from the page settings, then the site theme, then the '
              'built-in design.',
        ),
      PanelTab.visibility => (kVisibilityFields, node, base, null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tabs<PanelTab>(
          tabs: const {
            PanelTab.content: 'Content',
            PanelTab.layout: 'Layout',
            PanelTab.style: 'Style',
            PanelTab.typography: 'Type',
            PanelTab.visibility: 'Visibility',
          },
          current: tab,
          onChanged: onTab,
          badges: {PanelTab.content: mine.where((x) => x.isError).length},
        ),
        Expanded(
          child: _Scroll(
            title: spec.label,
            subtitle: spec.description,
            issues: mine,
            hint: hint,
            child: FieldForm(fields: fields, values: values, basePath: path, env: e),
          ),
        ),
      ],
    );
  }

  Widget _pageSettings() {
    final tab = _tab(ui.panelTab, const [PanelTab.content, PanelTab.typography, PanelTab.layout]);
    final (fields, values, path) = switch (tab) {
      PanelTab.content => (kSeoFields, _map(state.doc['seo']), <Object>['seo']),
      PanelTab.typography => (kThemeTypographyFields, _map(state.doc['typography']), <Object>['typography']),
      _ => (kThemeLayoutFields, _map(state.doc['layout']), <Object>['layout']),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tabs<PanelTab>(
          tabs: const {
            PanelTab.content: 'Search & title',
            PanelTab.typography: 'Type',
            PanelTab.layout: 'Layout',
          },
          current: tab,
          onChanged: onTab,
        ),
        Expanded(
          child: _Scroll(
            title: 'Page settings',
            subtitle: 'Apply to every section on this page. A section can override them.',
            issues: state.issues.where((x) => x.sectionId == null).toList(),
            child: FieldForm(fields: fields, values: values, basePath: path, env: env),
          ),
        ),
      ],
    );
  }

  // ── Theme ──

  Widget _themeTabs() {
    final tab = _tab(ui.panelTab, const [PanelTab.typography, PanelTab.layout]);
    final isType = tab == PanelTab.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tabs<PanelTab>(
          tabs: const {PanelTab.typography: 'Typography', PanelTab.layout: 'Layout & spacing'},
          current: tab,
          onChanged: onTab,
        ),
        Expanded(
          child: _Scroll(
            title: 'Site theme',
            subtitle: 'The base for every page. Pages and sections can override it.',
            issues: const [],
            hint: 'Brand colours are fixed by the design system and are not editable here. '
                'Sections can set their own background and heading colours.',
            child: FieldForm(
              fields: isType ? kThemeTypographyFields : kThemeLayoutFields,
              values: _map(state.doc[isType ? 'typography' : 'layout']),
              basePath: [isType ? 'typography' : 'layout'],
              env: env,
            ),
          ),
        ),
      ],
    );
  }

  PanelTab _tab(PanelTab wanted, List<PanelTab> allowed) => allowed.contains(wanted) ? wanted : allowed.first;

  Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

class _Tabs<T> extends StatelessWidget {
  const _Tabs({required this.tabs, required this.current, required this.onChanged, this.badges = const {}});

  final Map<T, String> tabs;
  final T current;
  final ValueChanged<T> onChanged;
  final Map<T, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SC.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in tabs.entries)
              InkWell(
                onTap: () => onChanged(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: e.key == current ? SC.accent : Colors.transparent, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: e.key == current ? FontWeight.w700 : FontWeight.w500,
                          color: e.key == current ? SC.accent : SC.muted,
                        ),
                      ),
                      if ((badges[e.key] ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        Chip2('${badges[e.key]}', color: SC.danger),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.title, required this.subtitle, required this.issues, required this.child, this.hint});

  final String title;
  final String subtitle;
  final List<ValidationIssue> issues;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: SC.title),
          const SizedBox(height: 2),
          Text(subtitle, style: SC.small),
          if (issues.isNotEmpty) ...[const SizedBox(height: 14), _IssueList(issues: issues)],
          if (hint != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: SC.accentBg, borderRadius: BorderRadius.circular(8)),
              child: Text(hint!, style: SC.small.copyWith(color: SC.text)),
            ),
          ],
          const SizedBox(height: 18),
          child,
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final List<ValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final i in issues)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: i.isError ? SC.dangerBg : SC.warnBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (i.isError ? SC.danger : SC.warn).withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(i.isError ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                    size: 16, color: i.isError ? SC.danger : SC.warn),
                const SizedBox(width: 8),
                Expanded(child: Text(i.message, style: SC.small.copyWith(color: SC.text))),
              ],
            ),
          ),
      ],
    );
  }
}
