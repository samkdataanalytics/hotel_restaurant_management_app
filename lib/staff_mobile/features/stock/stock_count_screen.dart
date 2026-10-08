import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/connectivity.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/offline_banner.dart';
import '../../data/table_realtime.dart';

final _stockProvider = FutureProvider.autoDispose<List<StockLine>>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  // Two tables: counts live in `inventory`, names and reorder levels in
  // `ingredients`. A stocktake split across two people has to converge.
  ref.watch(tableRealtimeProvider('inventory'));
  ref.watch(tableRealtimeProvider('ingredients'));
  return ref.watch(restaurantRepositoryProvider).loadStock();
});

/// Walk the store room entering counts.
///
/// Built for someone holding a phone in one hand and a clipboard's worth of
/// attention: counts are entered inline, nothing is written until the whole
/// count is submitted, and the variance against what the system expected is
/// shown as you go — because a count that is wildly off is usually a counting
/// mistake, and catching it in the store room is far cheaper than catching it
/// in next month's costings.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  /// Ingredient id to the figure typed. Absent means not counted yet, which is
  /// deliberately different from counted as zero.
  final _counts = <String, double>{};
  final _controllers = <String, TextEditingController>{};

  String _search = '';
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_stockProvider);
    final session = ref.watch(staffSessionProvider).valueOrNull;
    // Stock is menu-side data, so it follows the restaurant management section
    // rather than POS — a waiter should not be able to rewrite stock levels.
    final mayCount = session?.canEdit('restaurant_management') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock count'),
        actions: [
          if (_counts.isNotEmpty)
            TextButton(
              onPressed: _submitting ? null : () => setState(_counts.clear),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (!mayCount)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'View only — you cannot change stock levels.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search ingredients',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load stock.\n\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (lines) {
                final visible = _visible(lines);
                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        lines.isEmpty
                            ? 'No ingredients set up. Add them on the web '
                                'panel under Restaurant.'
                            : 'Nothing matches.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _StockRow(
                    line: visible[i],
                    controller: _controllerFor(visible[i].ingredient.id),
                    counted: _counts[visible[i].ingredient.id],
                    enabled: mayCount && !_submitting,
                    onChanged: (value) => setState(() {
                      if (value == null) {
                        _counts.remove(visible[i].ingredient.id);
                      } else {
                        _counts[visible[i].ingredient.id] = value;
                      }
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _counts.isEmpty
          ? null
          : _SubmitBar(
              countedLines: _counts.length,
              submitting: _submitting,
              onSubmit: () => _submit(async.valueOrNull ?? const []),
            ),
    );
  }

  List<StockLine> _visible(List<StockLine> lines) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return lines;
    return lines
        .where((l) => l.ingredient.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _submit(List<StockLine> lines) async {
    if (_counts.isEmpty || _submitting) return;

    final byId = {for (final l in lines) l.ingredient.id: l};
    final changed = _counts.entries
        .where((e) => byId.containsKey(e.key))
        .where((e) => e.value != byId[e.key]!.expected)
        .toList();

    if (changed.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Every count matched — nothing to adjust.'),
        ));
      setState(_counts.clear);
      return;
    }

    // Variances are shown before anything is written. A stock take that
    // silently rewrites forty figures is impossible to sanity-check after the
    // fact, and the whole point of counting is to notice the surprises.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply ${changed.length} adjustment'
            '${changed.length == 1 ? '' : 's'}?'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final entry in changed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(byId[entry.key]!.ingredient.name)),
                      Text(
                        _variance(entry.value - byId[entry.key]!.expected,
                            byId[entry.key]!.ingredient.unit),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: entry.value < byId[entry.key]!.expected
                              ? Theme.of(ctx).colorScheme.error
                              : StaffTheme.tableReady,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final repo = ref.read(restaurantRepositoryProvider);
    final isOnline = ref.read(isOnlineProvider);
    final failed = <String>[];

    for (final entry in changed) {
      try {
        await repo.applyStockCount(
          ingredientId: entry.key,
          expected: byId[entry.key]!.expected,
          counted: entry.value,
        );
      } catch (e) {
        failed.add(byId[entry.key]!.ingredient.name);
      }
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      // Only the ones that landed are cleared, so a retry re-sends exactly
      // what failed rather than everything.
      for (final entry in changed) {
        if (!failed.contains(byId[entry.key]!.ingredient.name)) {
          _counts.remove(entry.key);
          _controllers[entry.key]?.clear();
        }
      }
    });
    ref.invalidate(_stockProvider);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(failed.isEmpty
            ? 'Applied ${changed.length} adjustment'
                '${changed.length == 1 ? '' : 's'}'
            : '${failed.length} did not save: ${failed.take(3).join(', ')}'
                '${failed.length > 3 ? '…' : ''}'),
        backgroundColor:
            failed.isEmpty ? null : Theme.of(context).colorScheme.error,
        duration: Duration(seconds: failed.isEmpty ? 3 : 6),
      ));

    if (failed.isNotEmpty && !isOnline) {
      // Nothing here is queued: a stock figure replayed later would be applied
      // against a level that has moved since.
    }
  }

  static String _variance(double delta, String unit) {
    final sign = delta > 0 ? '+' : '';
    final value = delta == delta.roundToDouble()
        ? delta.toStringAsFixed(0)
        : delta.toStringAsFixed(2);
    return '$sign$value $unit';
  }
}

class _StockRow extends StatelessWidget {
  final StockLine line;
  final TextEditingController controller;
  final double? counted;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  const _StockRow({
    required this.line,
    required this.controller,
    required this.counted,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final variance = counted == null ? null : counted! - line.expected;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          line.ingredient.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (line.isLow) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.warning_amber_rounded,
                            size: 15, color: StaffTheme.tableBillRequested),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line.neverCounted
                        ? 'Never counted'
                        : 'Expected ${_num(line.expected)} ${line.ingredient.unit}',
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                  if (variance != null && variance != 0)
                    Text(
                      variance > 0
                          ? '+${_num(variance)} over'
                          : '${_num(variance)} short',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: variance < 0
                            ? scheme.error
                            : StaffTheme.tableReady,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: TextField(
                controller: controller,
                enabled: enabled,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  hintText: 'count',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                onChanged: (v) {
                  final trimmed = v.trim();
                  onChanged(trimmed.isEmpty ? null : double.tryParse(trimmed));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _num(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}

class _SubmitBar extends StatelessWidget {
  final int countedLines;
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.countedLines,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2))
                : const Icon(Icons.inventory_2_outlined),
            label: Text(submitting
                ? 'Applying'
                : 'Review $countedLines count'
                    '${countedLines == 1 ? '' : 's'}'),
          ),
        ),
      ),
    );
  }
}
