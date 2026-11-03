import 'package:flutter/material.dart';

import '../../../app_theme.dart';
import '../../../services/platform_tracking_service.dart';
import '../users/users_format.dart';

/// Small building blocks shared by the company, property and overview screens.

class TCard extends StatelessWidget {
  const TCard({super.key, required this.title, required this.children, this.width, this.trailing});

  final String title;
  final List<Widget> children;
  final double? width;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class TFact extends StatelessWidget {
  const TFact(this.label, this.value, {super.key, this.mono = false, this.onTap});

  final String label;
  final String value;
  final bool mono;

  /// Makes the value a link (to a company, a property, a person).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 128, child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted))),
            Expanded(
              child: onTap == null
                  ? SelectableText(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 12.5, color: const Color(0xFF1E293B), fontFamily: mono ? 'monospace' : null))
                  : InkWell(
                      onTap: onTap,
                      child: Text(value, style: TextStyle(fontSize: 12.5, color: AppTheme.brandTeal, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: AppTheme.brandTeal)),
                    ),
            ),
          ],
        ),
      );
}

class TMuted extends StatelessWidget {
  const TMuted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 12.5, color: AppTheme.adminTextMuted, height: 1.5));
}

class TPill extends StatelessWidget {
  const TPill(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: color == null ? 0.1 : 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}

/// A company or property status, coloured by what it means.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});

  final String status;

  static Color colorOf(String s) => switch (s) {
        'active' || 'success' || 'available' || 'served' || 'checkedOut' => AppTheme.statusGreen,
        'trialing' || 'pending' => AppTheme.statusBlue,
        'trial_expired' || 'inactive' || 'cancelled' => AppTheme.statusAmber,
        'suspended' || 'failed' || 'deleted' => AppTheme.statusRed,
        _ => const Color(0xFF64748B),
      };

  static String labelOf(String s) => s.isEmpty ? 'unknown' : s.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) => TPill(labelOf(status), color: colorOf(status));
}

class TStat extends StatelessWidget {
  const TStat({super.key, required this.label, required this.value, required this.icon, required this.color, this.sub, this.onTap, this.width = 190});

  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    Text(label, style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                    if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// "3 of 5" with a bar; red once over the cap.
class LimitMeter extends StatelessWidget {
  const LimitMeter({super.key, required this.label, required this.limit});

  final String label;
  final Limit limit;

  @override
  Widget build(BuildContext context) {
    final color = limit.over ? AppTheme.statusRed : (limit.fraction > 0.85 ? AppTheme.statusAmber : AppTheme.brandTeal);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Text(limit.unlimited ? '${limit.used} · unlimited' : '${limit.used} of ${limit.max}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: limit.over ? AppTheme.statusRed : const Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: limit.unlimited ? 0 : limit.fraction,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal bars for "what happened, how often".
class TallyBars extends StatelessWidget {
  const TallyBars({super.key, required this.rows, this.labelWidth = 170, this.empty = 'Nothing recorded in the last 30 days.'});

  final List<(String label, int count)> rows;
  final double labelWidth;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return TMuted(empty);
    final max = rows.fold<int>(1, (m, r) => r.$2 > m ? r.$2 : m);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: labelWidth, child: Text(r.$1, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: r.$2 / max, minHeight: 8, backgroundColor: const Color(0xFFF1F5F9), color: AppTheme.brandTeal),
                  ),
                ),
                SizedBox(width: 44, child: Text('${r.$2}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
      ],
    );
  }
}

/// "{status}: n" chips, e.g. rooms by status.
class CountChips extends StatelessWidget {
  const CountChips(this.counts, {super.key, this.empty = 'None'});

  final Map<String, int> counts;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return TMuted(empty);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in counts.entries) TPill('${StatusPill.labelOf(e.key)}  ${e.value}', color: StatusPill.colorOf(e.key)),
      ],
    );
  }
}

/// A person row: name, role, last sign-in, 30-day actions. Tapping opens them.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, this.onTap});

  final MemberRow person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.display, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                        [if (person.hasRealEmail) person.email, 'signed in ${relativeTime(person.lastSignInAt)}'].join('  ·  '),
                        style: TextStyle(fontSize: 11.5, color: AppTheme.adminTextMuted),
                      ),
                    ],
                  ),
                ),
                if (person.actions30d > 0)
                  Padding(padding: const EdgeInsets.only(right: 8), child: Text('${person.actions30d} actions', style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)))),
                TPill(person.role),
              ],
            ),
          ),
        ),
      );
}

String money(num v, [String currency = '']) {
  final s = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);
  final withCommas = s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return currency.isEmpty ? withCommas : '$currency $withCommas';
}
