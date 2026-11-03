import 'package:flutter/material.dart';

import '../../cms/data/site_repository.dart';
import '../specs/section_specs.dart';
import '../studio_diff.dart';
import '../studio_state.dart';
import '../studio_theme.dart';
import '../studio_validation.dart';

// ── Add section ──────────────────────────────────────────────────────────────

final _addable = [for (final s in kSectionSpecs) if (s.addable) s];

Future<SectionSpec?> showAddSectionDialog(BuildContext context) {
  return showDialog<SectionSpec>(
    context: context,
    builder: (c) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Add a section', style: SC.title),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('It is added below the selected section, with starter content you can edit.', style: SC.small),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 134,
                  ),
                  itemCount: _addable.length,
                  itemBuilder: (_, i) {
                    final s = _addable[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(c, s),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SC.border),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(color: SC.accentBg, borderRadius: BorderRadius.circular(8)),
                              child: Icon(s.icon, size: 18, color: SC.accent),
                            ),
                            const SizedBox(height: 10),
                            Text(s.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: SC.text)),
                            const SizedBox(height: 2),
                            Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: SC.small),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Confirm ──────────────────────────────────────────────────────────────────

Future<bool> confirm(BuildContext context,
    {required String title, required String body, String action = 'Confirm', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? SC.danger : SC.accent),
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

// ── Publish ──────────────────────────────────────────────────────────────────

/// Shows what will change and what to double-check, and asks for a note.
/// Returns the note, or null if cancelled.
Future<String?> showPublishDialog(
  BuildContext context, {
  required String pageLabel,
  required Map<String, dynamic> published,
  required Map<String, dynamic> draft,
  required List<ValidationIssue> issues,
  required bool noteRequired,
}) {
  return showDialog<String>(
    context: context,
    builder: (c) => _PublishDialog(
      pageLabel: pageLabel,
      changes: summarizeChanges(published, draft),
      warnings: issues.where((i) => !i.isError).toList(),
      claims: collectUnverifiedClaims(draft),
      noteRequired: noteRequired,
    ),
  );
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog({
    required this.pageLabel,
    required this.changes,
    required this.warnings,
    required this.claims,
    required this.noteRequired,
  });

  final String pageLabel;
  final List<String> changes;
  final List<ValidationIssue> warnings;
  final List<UnverifiedClaim> claims;
  final bool noteRequired;

  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  final _note = TextEditingController();
  bool _acknowledged = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ready =>
      (!widget.noteRequired || _note.text.trim().isNotEmpty) &&
      (widget.claims.isEmpty || _acknowledged);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Publish ${widget.pageLabel}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This goes live for every visitor straight away. You can restore an earlier version afterwards.',
                  style: SC.small),
              const SizedBox(height: 14),
              const Text('What will change', style: SC.label),
              const SizedBox(height: 6),
              if (widget.changes.isEmpty)
                const Text('Nothing differs from the live page.', style: SC.small)
              else
                for (final l in widget.changes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: SC.accent)),
                        Expanded(child: Text(l, style: SC.body)),
                      ],
                    ),
                  ),
              if (widget.warnings.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Box(
                  color: SC.warn,
                  bg: SC.warnBg,
                  title: '${widget.warnings.length} warning(s)',
                  lines: [for (final w in widget.warnings) w.message],
                ),
              ],
              if (widget.claims.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Box(
                  color: SC.warn,
                  bg: SC.warnBg,
                  title: 'Claims to confirm before publishing',
                  lines: [for (final c in widget.claims) '${c.sectionLabel} — ${c.field}: ${c.message}'],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  title: const Text('I have checked these and they are true today.', style: SC.body),
                ),
              ],
              const SizedBox(height: 12),
              Text(widget.noteRequired ? 'Note (required for legal pages)' : 'Note (optional)', style: SC.label),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: SC.input(hint: 'What changed, and why'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _ready ? () => Navigator.pop(context, _note.text.trim()) : null,
          style: FilledButton.styleFrom(backgroundColor: SC.accent),
          child: const Text('Publish'),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.color, required this.bg, required this.title, required this.lines});

  final Color color;
  final Color bg;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: SC.label),
            ]),
            const SizedBox(height: 6),
            for (final l in lines)
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: SC.small.copyWith(color: SC.text))),
          ],
        ),
      );
}

// ── Revisions ────────────────────────────────────────────────────────────────

Future<void> showRevisionsDialog(
  BuildContext context, {
  required String pageLabel,
  required Future<List<RevisionInfo>> Function() load,
  required Future<void> Function(int rev) onRestore,
}) {
  return showDialog<void>(
    context: context,
    builder: (c) => _RevisionsDialog(pageLabel: pageLabel, load: load, onRestore: onRestore),
  );
}

class _RevisionsDialog extends StatefulWidget {
  const _RevisionsDialog({required this.pageLabel, required this.load, required this.onRestore});

  final String pageLabel;
  final Future<List<RevisionInfo>> Function() load;
  final Future<void> Function(int rev) onRestore;

  @override
  State<_RevisionsDialog> createState() => _RevisionsDialogState();
}

class _RevisionsDialogState extends State<_RevisionsDialog> {
  late final Future<List<RevisionInfo>> _future = widget.load();

  String _when(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('History — ${widget.pageLabel}'),
      content: SizedBox(
        width: 540,
        height: 420,
        child: FutureBuilder<List<RevisionInfo>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            if (snap.hasError) {
              return Center(child: Text('Could not load the history: ${snap.error}', style: SC.small));
            }
            final revs = snap.data!;
            if (revs.isEmpty) {
              return const Center(child: Text('Nothing has been published yet.', style: SC.small));
            }
            return ListView.separated(
              itemCount: revs.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: SC.border),
              itemBuilder: (_, i) {
                final r = revs[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Text('Version ${r.rev}', style: SC.body.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Chip2(r.action, color: r.action == 'publish' ? SC.ok : SC.muted),
                    ],
                  ),
                  subtitle: Text('${_when(r.createdAt)}${r.note.isEmpty ? '' : ' · ${r.note}'}', style: SC.small),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Restore version ${r.rev}?',
                        body: 'It is loaded into your working copy so you can look at it. '
                            'Nothing goes live until you publish.',
                        action: 'Restore into draft',
                      );
                      if (!ok) return;
                      await widget.onRestore(r.rev);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Restore'),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
