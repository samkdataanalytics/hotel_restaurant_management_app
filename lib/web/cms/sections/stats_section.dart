import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../model/site_document.dart';
import '../registry/section_registry.dart';

class StatItem {
  const StatItem({
    required this.value,
    required this.suffix,
    required this.decimals,
    required this.label,
  });

  factory StatItem.fromJson(J j) => StatItem(
        value: j.dbl('value'),
        suffix: j.str('suffix'),
        // Clamped so a typo cannot ask toStringAsFixed for 40 places.
        decimals: j.integer('decimals').clamp(0, 3),
        label: j.str('label'),
      );

  final double value;
  final String suffix;
  final int decimals;
  final String label;
}

class StatsContent {
  const StatsContent({required this.items});

  factory StatsContent.fromJson(J j) => StatsContent(
        items: j.list('items', StatItem.fromJson).where((s) => s.label.isNotEmpty).toList(),
      );

  final List<StatItem> items;
}

final statsDefinition = SectionDefinition(
  type: 'stats',
  label: 'Stats strip',
  builder: (context, SectionNode node) =>
      StatsSection(content: StatsContent.fromJson(node.content)),
);

class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.content});

  final StatsContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return Shell(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: mobile ? 28 : 34, horizontal: mobile ? 18 : 30),
        decoration: BoxDecoration(
          color: LK.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LK.line),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 24,
          runSpacing: 24,
          children: [
            for (final s in content.items)
              SizedBox(
                width: mobile ? 150 : 190,
                child: Column(
                  children: [
                    CountUp(
                      value: s.value,
                      suffix: s.suffix,
                      decimals: s.decimals,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: LK.navy,
                        fontSize: mobile ? 26 : 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.label, style: LK.micro, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
