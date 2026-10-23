import 'package:flutter/material.dart';

import '../../cms/model/json_reader.dart';
import '../specs/section_specs.dart';
import '../studio_state.dart';
import '../studio_theme.dart';

/// The ordered list of a page's sections: select, reorder, hide, duplicate, delete.
class SectionList extends StatelessWidget {
  const SectionList({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.issues,
    required this.onSelect,
    required this.onToggle,
    required this.onDuplicate,
    required this.onDelete,
    required this.onReorder,
    required this.onAdd,
    required this.onPageSettings,
    required this.pageSettingsSelected,
  });

  final List<Map<String, dynamic>> sections;
  final String? selectedId;
  final List<ValidationIssue> issues;
  final ValueChanged<String> onSelect;
  final void Function(String id, bool enabled) onToggle;
  final ValueChanged<String> onDuplicate;
  final ValueChanged<String> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;
  final VoidCallback onPageSettings;
  final bool pageSettingsSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: _PageRow(selected: pageSettingsSelected, onTap: onPageSettings),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text('SECTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: SC.faint)),
        ),
        Expanded(
          child: sections.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('This page has no sections yet. Add one to start.', textAlign: TextAlign.center, style: SC.small),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: sections.length,
                  onReorderItem: onReorder,
                  proxyDecorator: (child, _, __) => Material(
                    color: Colors.transparent,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final s = sections[i];
                    final id = s['id'] as String? ?? '';
                    return _SectionRow(
                      key: ValueKey('row-$id'),
                      index: i,
                      node: s,
                      selected: id == selectedId,
                      errors: issues.where((x) => x.sectionId == id && x.isError).length,
                      warnings: issues.where((x) => x.sectionId == id && !x.isError).length,
                      onTap: () => onSelect(id),
                      onToggle: (v) => onToggle(id, v),
                      onDuplicate: () => onDuplicate(id),
                      onDelete: () => onDelete(id),
                    );
                  },
                ),
        ),
        const Divider(height: 1, color: SC.border),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: SC.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add section'),
          ),
        ),
      ],
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? SC.accentBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? SC.accent : SC.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: SC.accent),
              SizedBox(width: 10),
              Expanded(
                child: Text('Page settings', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: SC.text)),
              ),
              Text('Title, fonts, layout', style: SC.small),
            ],
          ),
        ),
      );
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.index,
    required this.node,
    required this.selected,
    required this.errors,
    required this.warnings,
    required this.onTap,
    required this.onToggle,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final Map<String, dynamic> node;
  final bool selected;
  final int errors;
  final int warnings;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final type = node['type'] as String? ?? '';
    final spec = kSectionSpecByType[type];
    final enabled = node['enabled'] != false;
    final content = J.of(node['content']);
    final subtitle = content.strOrNull('title') ?? content.strOrNull('headline') ?? content.strOrNull('eyebrow') ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? SC.accentBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? SC.accent : SC.border),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(Icons.drag_indicator_rounded, size: 18, color: SC.faint),
                    ),
                  ),
                ),
                Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: Icon(spec?.icon ?? Icons.help_outline_rounded, size: 19, color: selected ? SC.accent : SC.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(spec?.label ?? 'Unknown ($type)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SC.text)),
                        if (subtitle.isNotEmpty)
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: SC.small),
                      ],
                    ),
                  ),
                ),
                if (errors > 0)
                  Tooltip(message: '$errors problem(s) to fix', child: Chip2('$errors', color: SC.danger, icon: Icons.error_outline_rounded))
                else if (warnings > 0)
                  Tooltip(message: '$warnings warning(s)', child: Chip2('$warnings', color: SC.warn, icon: Icons.warning_amber_rounded)),
                IconButton(
                  tooltip: enabled ? 'Hide from the site' : 'Show on the site',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => onToggle(!enabled),
                  icon: Icon(enabled ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: enabled ? SC.muted : SC.warn),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: SC.muted),
                  padding: EdgeInsets.zero,
                  onSelected: (v) => v == 'dup' ? onDuplicate() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                    PopupMenuItem(value: 'del', child: Text('Delete', style: TextStyle(color: SC.danger))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
