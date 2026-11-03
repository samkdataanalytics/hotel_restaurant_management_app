import 'package:flutter/material.dart';

import '../../brand_kit.dart';
import '../model/json_reader.dart';
import '../registry/icon_registry.dart';

class MockKpi {
  const MockKpi({required this.label, required this.value, required this.delta});

  factory MockKpi.fromJson(J j) =>
      MockKpi(label: j.str('label'), value: j.str('value'), delta: j.str('delta'));

  final String label;
  final String value;
  final String delta;
}

class MockFloat {
  const MockFloat({required this.icon, required this.tint, required this.title, required this.sub});

  factory MockFloat.fromJson(J j) => MockFloat(
        icon: IconRegistry.resolve(j.strOrNull('icon')),
        tint: j.str('tone') == 'navy' ? LK.navy : LK.teal,
        title: j.str('title'),
        sub: j.str('sub'),
      );

  final IconData icon;
  final Color tint;
  final String title;
  final String sub;
}

/// Everything the hero's product window shows. It is an illustration, so every
/// figure in it is editable: nothing here is live data.
class ProductMockContent {
  const ProductMockContent({
    required this.url,
    required this.greeting,
    required this.property,
    required this.liveLabel,
    required this.kpis,
    required this.chartTitle,
    required this.bars,
    required this.days,
    required this.rooms,
    required this.floats,
  });

  factory ProductMockContent.fromJson(J j) => ProductMockContent(
        url: j.str('url'),
        greeting: j.str('greeting'),
        property: j.str('property'),
        liveLabel: j.str('liveLabel'),
        kpis: j.list('kpis', MockKpi.fromJson).take(3).toList(),
        chartTitle: j.str('chartTitle'),
        // Heights are fractions of the chart; clamped so a stray 40 cannot
        // draw a bar taller than the window.
        bars: [
          for (final v in (j.raw['bars'] is List ? j.raw['bars'] as List : const []))
            if (v is num) v.toDouble().clamp(0.0, 1.0),
        ],
        days: j.strings('days'),
        rooms: [
          for (final v in (j.raw['rooms'] is List ? j.raw['rooms'] as List : const []))
            if (v is num) v.toInt().clamp(0, 2),
        ],
        floats: j.list('floats', MockFloat.fromJson).take(2).toList(),
      );

  final String url;
  final String greeting;
  final String property;
  final String liveLabel;
  final List<MockKpi> kpis;
  final String chartTitle;

  /// 0..1 bar heights, one per day.
  final List<double> bars;
  final List<String> days;

  /// 0 free, 1 occupied, 2 cleaning.
  final List<int> rooms;

  /// Up to two callouts floating over the window (desktop only).
  final List<MockFloat> floats;
}

/// Stylised product window used as the hero visual.
///
/// Drawn in Flutter rather than shipped as a screenshot: a real screenshot
/// would date the moment the panel changes, would need re-exporting per
/// breakpoint, and would carry whatever test data happened to be on screen.
class ProductMock extends StatelessWidget {
  const ProductMock({super.key, required this.content});

  final ProductMockContent content;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: LK.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LK.line),
              boxShadow: [
                BoxShadow(
                  color: LK.navy.withValues(alpha: 0.13),
                  blurRadius: 60,
                  offset: const Offset(0, 28),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Window chrome
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(
                    color: LK.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                    border: Border(bottom: BorderSide(color: LK.line)),
                  ),
                  child: Row(
                    children: [
                      for (final c in const [
                        Color(0xFFFF5F57),
                        Color(0xFFFEBC2E),
                        Color(0xFF28C840)
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: LK.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: LK.line),
                          ),
                          alignment: Alignment.center,
                          child: Text(content.url, style: LK.micro.copyWith(fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(content.greeting,
                                    style: LK.h3(context).copyWith(fontSize: 15)),
                                Text(content.property, style: LK.micro.copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          if (content.liveLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: LK.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(content.liveLabel,
                                  style: LK.micro.copyWith(
                                      fontSize: 10, color: LK.teal, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      if (content.kpis.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (var i = 0; i < content.kpis.length; i++) ...[
                              if (i > 0) const SizedBox(width: 9),
                              Expanded(child: _MiniKpi(kpi: content.kpis[i])),
                            ],
                          ],
                        ),
                      ],
                      if (content.bars.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _MiniChart(
                            title: content.chartTitle, bars: content.bars, days: content.days),
                      ],
                      if (content.rooms.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _MiniRooms(states: content.rooms),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Floating cards give the flat window depth and call out two
          // specifics the headline claims.
          if (!mobile) ...[
            if (content.floats.isNotEmpty)
              Positioned(
                left: -34,
                // Anchored from the bottom, not the top: the window's height
                // shifts with how the KPI labels wrap, so a top offset lands in
                // a different band at different widths — it was sitting on top
                // of the occupancy figure.
                bottom: 112,
                child: _FloatCard(float: content.floats[0]),
              ),
            if (content.floats.length > 1)
              Positioned(
                right: -26,
                bottom: 56,
                child: _FloatCard(float: content.floats[1]),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final MockKpi kpi;
  const _MiniKpi({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LK.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kpi.label, style: LK.micro.copyWith(fontSize: 9.5)),
          const SizedBox(height: 3),
          Text(kpi.value,
              style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: LK.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(kpi.delta,
              style: LK.micro.copyWith(fontSize: 9.5, color: LK.teal, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final String title;
  final List<double> bars;
  final List<String> days;
  const _MiniChart({required this.title, required this.bars, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: LK.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LK.micro.copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    // The tallest bars plus their label are a few pixels taller than
                    // the 56px track. As a plain Column that was reported as an
                    // overflow; it drew bottom-aligned when it fitted and from the
                    // top when it did not. This lays out the same way, as stated
                    // behaviour rather than an overflow error.
                    child: CustomSingleChildLayout(
                      delegate: const _BottomUnlessTall(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 46 * bars[i],
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  LK.tealPure,
                                  LK.tealPure.withValues(alpha: 0.45),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(i < days.length ? days[i] : '',
                              style: LK.micro.copyWith(fontSize: 8.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-aligns its child, or top-aligns it when the child is taller than the
/// space, letting it run past the bottom edge instead of overflowing.
class _BottomUnlessTall extends SingleChildLayoutDelegate {
  const _BottomUnlessTall();

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints(minWidth: c.maxWidth, maxWidth: c.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(0, (size.height - childSize.height).clamp(0.0, double.infinity));

  @override
  bool shouldRelayout(_BottomUnlessTall old) => false;
}

class _MiniRooms extends StatelessWidget {
  final List<int> states;
  const _MiniRooms({required this.states});

  @override
  Widget build(BuildContext context) {
    Color tint(int s) => switch (s) {
          1 => LK.navy,
          2 => LK.amber,
          _ => LK.teal,
        };

    return Row(
      children: [
        for (var i = 0; i < states.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: tint(states[i]).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: tint(states[i]).withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FloatCard extends StatelessWidget {
  final MockFloat float;
  const _FloatCard({required this.float});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: LK.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: LK.line),
        boxShadow: [
          BoxShadow(
            color: LK.ink.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: float.tint.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(float.icon, size: 15, color: float.tint),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(float.title,
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: LK.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              Text(float.sub, style: LK.micro.copyWith(fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}
