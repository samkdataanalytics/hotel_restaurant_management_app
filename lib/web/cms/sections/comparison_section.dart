import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brand_kit.dart';
import '../data/plans_provider.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';
import 'section_head_content.dart';

/// Text shown for `{starterPrice}` until the real Starter price has loaded, or
/// when it cannot be loaded.
const kStarterPriceFallback = 'from LKR 3,450';

class ComparisonColumn {
  const ComparisonColumn({required this.name, required this.short});

  factory ComparisonColumn.fromJson(J j) {
    final name = j.str('name');
    return ComparisonColumn(name: name, short: j.strOrNull('short') ?? name);
  }

  final String name;

  /// Label on the phone layout, where three full names do not fit.
  final String short;
}

/// One cell: a tick (true), a dash (false) or text.
typedef ComparisonCell = Object;

class ComparisonRow {
  const ComparisonRow({required this.label, required this.cells});

  factory ComparisonRow.fromJson(J j, int columns) {
    final raw = j.raw['cells'];
    final cells = <ComparisonCell>[
      for (var i = 0; i < columns; i++)
        if (raw is List && i < raw.length && (raw[i] is bool || raw[i] is String))
          raw[i] as Object
        else
          '',
    ];
    return ComparisonRow(label: j.str('label'), cells: cells);
  }

  final String label;
  final List<ComparisonCell> cells;
}

class ComparisonContent {
  const ComparisonContent({required this.head, required this.columns, required this.rows});

  factory ComparisonContent.fromJson(J j) {
    final columns = j.list('columns', ComparisonColumn.fromJson);
    return ComparisonContent(
      head: HeadContent.fromJson(j),
      columns: columns,
      rows: j
          .list('rows', (r) => ComparisonRow.fromJson(r, columns.length))
          .where((r) => r.label.isNotEmpty)
          .toList(),
    );
  }

  final HeadContent head;

  /// The first column is "ours" and is highlighted.
  final List<ComparisonColumn> columns;
  final List<ComparisonRow> rows;
}

final comparisonDefinition = SectionDefinition(
  type: 'comparison',
  label: 'Comparison table',
  builder: (context, SectionNode node) =>
      ComparisonSection(content: ComparisonContent.fromJson(node.content)),
);

class ComparisonSection extends ConsumerWidget {
  const ComparisonSection({super.key, required this.content});

  final ComparisonContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mobile = LK.isMobile(context);

    // Keeps the headline price honest against whatever the Starter plan
    // actually costs, rather than hardcoding it into marketing copy.
    final price = ref.watch(starterMonthlyPriceProvider).valueOrNull;
    final starter = price == null ? kStarterPriceFallback : 'LKR ${formatThousands(price)}';
    ComparisonCell fill(ComparisonCell c) =>
        c is String ? c.replaceAll('{starterPrice}', starter) : c;

    return Container(
      width: double.infinity,
      color: LK.ink,
      padding: EdgeInsets.symmetric(vertical: mobile ? 72 : 110),
      child: Stack(
        children: [
          const Positioned.fill(
            child: MeshBackdrop(blobs: [
              (at: Alignment(-0.9, -0.9), color: LK.tealPure, size: 620, opacity: 0.14),
              (at: Alignment(1.0, 1.0), color: LK.navy, size: 700, opacity: 0.4),
            ]),
          ),
          Shell(
            child: Column(
              children: [
                SectionHead(
                  eyebrow: content.head.eyebrow,
                  title: content.head.title,
                  lead: content.head.lead,
                  onDark: true,
                ),
                SizedBox(height: mobile ? 36 : 52),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: mobile
                      ? _MobileTable(content: content, fill: fill)
                      : _DesktopTable(content: content, fill: fill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _cell(ComparisonCell v, {required bool ours}) {
  if (v is bool) {
    return Icon(
      v ? Icons.check_circle_rounded : Icons.remove_rounded,
      size: 19,
      color: v
          ? (ours ? LK.tealLift : Colors.white.withValues(alpha: 0.4))
          : Colors.white.withValues(alpha: 0.2),
    );
  }
  return Text(
    '$v',
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Outfit',
      color: ours ? LK.tealLift : Colors.white.withValues(alpha: 0.6),
      fontSize: 13,
      fontWeight: ours ? FontWeight.w700 : FontWeight.w500,
    ),
  );
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.content, required this.fill});

  final ComparisonContent content;
  final ComparisonCell Function(ComparisonCell) fill;

  @override
  Widget build(BuildContext context) {
    final columns = content.columns;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: Row(
              children: [
                const Expanded(flex: 34, child: SizedBox()),
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: 22,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: i == 0
                          ? BoxDecoration(
                              color: LK.tealLift.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: LK.tealLift.withValues(alpha: 0.35)),
                            )
                          : null,
                      child: Text(
                        columns[i].name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: i == 0 ? LK.tealLift : Colors.white.withValues(alpha: 0.55),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var r = 0; r < content.rows.length; r++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: r.isEven ? Colors.white.withValues(alpha: 0.02) : null,
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 34,
                    child: Text(
                      content.rows[r].label,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  for (var c = 0; c < columns.length; c++)
                    Expanded(
                      flex: 22,
                      child: Center(
                        child: _cell(fill(content.rows[r].cells[c]), ours: c == 0),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileTable extends StatelessWidget {
  const _MobileTable({required this.content, required this.fill});

  final ComparisonContent content;
  final ComparisonCell Function(ComparisonCell) fill;

  // On a phone the multi-column grid collapses into unreadable slivers, so
  // each row becomes its own small card.
  @override
  Widget build(BuildContext context) {
    final columns = content.columns;

    return Column(
      children: [
        for (final row in content.rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var c = 0; c < columns.length; c++)
                      Expanded(child: _miniCol(columns[c].short, fill(row.cells[c]), c == 0)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _miniCol(String head, ComparisonCell v, bool ours) => Column(
        children: [
          Text(head,
              style: LK.micro.copyWith(
                  fontSize: 10,
                  color: ours ? LK.tealLift : Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          _cell(v, ours: ours),
        ],
      );
}
