import 'dart:async';

import 'package:flutter/material.dart';
import '../../brand_kit.dart' show motionStill;
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../model/tokens.dart';
import '../registry/section_registry.dart';

// The help page keeps the slate palette it always had.
const _bg = Color(0xFFFFFFFF);
const _surface = Color(0xFFF8FAFC);
const _card = Color(0xFFFFFFFF);
const _border = Color(0xFFE2E8F0);
const _text = Color(0xFF0F172A);
const _sub = Color(0xFF64748B);
const _gold = Color(0xFF0A7D77);
const _finance = Color(0xFF10B981);

/// Category colours an admin can choose from, by name. A name, not a hex value, so
/// the help page cannot end up with a category nobody can read.
const kHelpTones = {
  'blue': Color(0xFF3B82F6),
  'orange': Color(0xFFF97316),
  'pink': Color(0xFFEC4899),
  'green': Color(0xFF10B981),
  'purple': Color(0xFF8B5CF6),
  'slate': Color(0xFF64748B),
  'teal': Color(0xFF0A7D77),
};

class HelpStep {
  const HelpStep({required this.title, required this.body, this.tip, this.note});

  factory HelpStep.fromJson(J j) => HelpStep(
        title: j.str('title'),
        body: j.str('body'),
        tip: j.strOrNull('tip'),
        note: j.strOrNull('note'),
      );

  final String title;
  final String body;
  final String? tip;
  final String? note;
}

class HelpCategory {
  const HelpCategory({required this.name, required this.color});

  factory HelpCategory.fromJson(J j) =>
      HelpCategory(name: j.str('name'), color: kHelpTones[j.str('tone')] ?? _gold);

  final String name;
  final Color color;
}

class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.color,
    required this.steps,
  });

  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final String category;
  final Color color;
  final List<HelpStep> steps;

  int get readMinutes => ((steps.length * 25) / 60).ceil().clamp(1, 10);
}

class HelpContent {
  const HelpContent({
    required this.title,
    required this.subtitle,
    required this.backLabel,
    required this.signInLabel,
    required this.allLabel,
    required this.exploredLabel,
    required this.readTimeLabel,
    required this.stepsFooter,
    required this.tipLabel,
    required this.noteLabel,
    required this.noResultsTitle,
    required this.noResultsHint,
    required this.searchHints,
    required this.categories,
    required this.topics,
  });

  factory HelpContent.fromJson(J j) {
    final categories = j.list('categories', HelpCategory.fromJson).where((c) => c.name.isNotEmpty).toList();
    final colorOf = {for (final c in categories) c.name: c.color};
    final seen = <String>{};
    final topics = <HelpTopic>[];
    for (final t in j.list('topics', (x) => x)) {
      final id = t.str('id');
      final title = t.str('title');
      // A topic needs a title and an id nobody else has: the id keys which card
      // is open.
      if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
      final category = t.str('category');
      topics.add(HelpTopic(
        id: id,
        emoji: t.str('emoji'),
        title: title,
        subtitle: t.str('subtitle'),
        category: category,
        color: colorOf[category] ?? _gold,
        steps: t.list('steps', HelpStep.fromJson).where((s) => s.title.isNotEmpty).toList(),
      ));
    }
    return HelpContent(
      title: j.str('title'),
      subtitle: j.str('subtitle'),
      backLabel: j.str('backLabel', 'Back to home'),
      signInLabel: j.str('signInLabel', 'Sign In'),
      allLabel: j.str('allLabel', 'All'),
      exploredLabel: j.str('exploredLabel'),
      readTimeLabel: j.str('readTimeLabel', '~{minutes} min'),
      stepsFooter: j.str('stepsFooter', '{steps} steps · {category}'),
      tipLabel: j.str('tipLabel', 'Tip'),
      noteLabel: j.str('noteLabel', 'Note'),
      noResultsTitle: j.str('noResultsTitle', 'No results for "{query}"'),
      noResultsHint: j.str('noResultsHint'),
      searchHints: j.strings('searchHints').where((s) => s.isNotEmpty).toList(),
      categories: categories,
      topics: topics,
    );
  }

  final String title;
  final String subtitle;
  final String backLabel;
  final String signInLabel;
  final String allLabel;
  final String exploredLabel;
  final String readTimeLabel;
  final String stepsFooter;
  final String tipLabel;
  final String noteLabel;
  final String noResultsTitle;
  final String noResultsHint;
  final List<String> searchHints;
  final List<HelpCategory> categories;
  final List<HelpTopic> topics;

  Color colorFor(String category) {
    for (final c in categories) {
      if (c.name == category) return c.color;
    }
    return _gold;
  }
}

final helpTopicsDefinition = SectionDefinition(
  type: 'helpTopics',
  label: 'Help topics',
  builder: (context, SectionNode node) => HelpTopicsSection(content: HelpContent.fromJson(node.content)),
);

/// The searchable list of help topics. Search, filters and the open card are the
/// visitor's, not content; the topics, categories and wording are.
class HelpTopicsSection extends StatefulWidget {
  const HelpTopicsSection({super.key, required this.content, this.searchFocus});

  final HelpContent content;

  /// Lets the page focus the search box (the "/" shortcut).
  final FocusNode? searchFocus;

  @override
  State<HelpTopicsSection> createState() => _HelpTopicsSectionState();
}

class _HelpTopicsSectionState extends State<HelpTopicsSection> {
  String _query = '';
  String? _category; // null = all
  String? _expandedId;
  int _hintIdx = 0;
  final Set<String> _opened = {};
  final _searchCtrl = TextEditingController();
  late final FocusNode _ownFocus = FocusNode();
  Timer? _hintTimer;

  FocusNode get _focus => widget.searchFocus ?? _ownFocus;
  HelpContent get c => widget.content;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || c.searchHints.length < 2) return;
      // Frozen in the editor preview and tests: a timer that keeps firing would
      // stop a test from ever settling.
      if (motionStill(context)) return;
      setState(() => _hintIdx = (_hintIdx + 1) % c.searchHints.length);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _searchCtrl.dispose();
    _ownFocus.dispose();
    super.dispose();
  }

  List<HelpTopic> get _filtered {
    return c.topics.where((t) {
      if (_category != null && t.category != _category) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.steps.any((s) => s.title.toLowerCase().contains(q) || s.body.toLowerCase().contains(q));
    }).toList();
  }

  String _fill(String template, Map<String, String> vars) => expandTokens(template, vars);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          _categoryRow(),
          _results(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ── Header ──

  Widget _header() {
    final hint = c.searchHints.isEmpty ? '' : c.searchHints[_hintIdx % c.searchHints.length];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
        ),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0D9B94), Color(0xFF0A7D77)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: const Color(0xFF0A7D77).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: const TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text(_fill(c.subtitle, {'topicCount': '${c.topics.length}'}), style: const TextStyle(color: _sub, fontSize: 13)),
          ]),
          const Spacer(),
          if (_opened.isNotEmpty && c.exploredLabel.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _finance.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _finance.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎯', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(_fill(c.exploredLabel, {'opened': '${_opened.length}', 'total': '${c.topics.length}'}),
                    style: const TextStyle(color: _finance, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _focus,
            style: const TextStyle(color: _text, fontSize: 15),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _sub, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _sub, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: _sub, size: 18),
                      onPressed: () => setState(() {
                        _query = '';
                        _searchCtrl.clear();
                      }),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: _border),
                      ),
                      child: const Text('/', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Category chips ──

  Widget _categoryRow() {
    final chips = <(String?, String, Color)>[
      (null, c.allLabel, _gold),
      for (final cat in c.categories) (cat.name, cat.name, cat.color),
    ];
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((e) {
          final (value, label, color) = e;
          final selected = _category == value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: () => setState(() => _category = value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.18) : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color.withValues(alpha: 0.6) : _border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : _sub,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Results ──

  Widget _results() {
    final topics = _filtered;
    if (topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(_fill(c.noResultsTitle, {'query': _query}),
                style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(c.noResultsHint, style: const TextStyle(color: _sub, fontSize: 13)),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: topics
              .map((t) => SizedBox(
                    width: cardWidth,
                    child: _TopicCard(
                      topic: t,
                      content: c,
                      isExpanded: _expandedId == t.id,
                      onTap: () => setState(() {
                        _expandedId = _expandedId == t.id ? null : t.id;
                        _opened.add(t.id);
                      }),
                    ),
                  ))
              .toList(),
        );
      }),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final HelpTopic topic;
  final HelpContent content;
  final bool isExpanded;
  final VoidCallback onTap;
  const _TopicCard({required this.topic, required this.content, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isExpanded ? _card : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? topic.color.withValues(alpha: 0.5) : _border,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
            ? [BoxShadow(color: topic.color.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: 2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: topic.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: topic.color.withValues(alpha: 0.2)),
                    ),
                    child: Center(child: Text(topic.emoji, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(topic.title, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(topic.subtitle,
                          style: const TextStyle(color: _sub, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: topic.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(topic.category, style: TextStyle(color: topic.color, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Text(expandTokens(content.readTimeLabel, {'minutes': '${topic.readMinutes}'}),
                        style: const TextStyle(color: _sub, fontSize: 10)),
                  ]),
                ]),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              color: isExpanded ? topic.color.withValues(alpha: 0.4) : Colors.transparent,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded ? _steps() : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _steps() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...topic.steps.asMap().entries.map((e) => _StepRow(
                step: e.value,
                index: e.key,
                total: topic.steps.length,
                accentColor: topic.color,
                content: content,
              )),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 14, color: topic.color),
            const SizedBox(width: 6),
            Text(
              expandTokens(content.stepsFooter, {'steps': '${topic.steps.length}', 'category': topic.category}),
              style: TextStyle(color: topic.color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final HelpStep step;
  final int index;
  final int total;
  final Color accentColor;
  final HelpContent content;
  const _StepRow({required this.step, required this.index, required this.total, required this.accentColor, required this.content});

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text('${index + 1}', style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: accentColor.withValues(alpha: 0.15),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 3),
              Text(step.title, style: const TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(step.body, style: const TextStyle(color: _sub, fontSize: 12, height: 1.55)),
              if (step.tip != null) ...[
                const SizedBox(height: 8),
                _InfoBox(text: step.tip!, label: content.tipLabel, isNote: false),
              ],
              if (step.note != null) ...[
                const SizedBox(height: 8),
                _InfoBox(text: step.note!, label: content.noteLabel, isNote: true),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  final String label;
  final bool isNote; // true = blue note, false = amber tip
  const _InfoBox({required this.text, required this.label, required this.isNote});

  @override
  Widget build(BuildContext context) {
    final color = isNote ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24);
    final icon = isNote ? Icons.info_outline_rounded : Icons.lightbulb_outline_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$label: ', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                TextSpan(text: text, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11, height: 1.5)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
