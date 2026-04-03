import 'package:flutter/material.dart';
import '../../app_theme.dart';

// ─── Shimmer engine ───────────────────────────────────────────────────────────
//
// Wrap any skeleton layout with [Skeleton] to get a single, shared
// left-to-right sweep animation. All [SkeletonBox] descendants share
// the same timing, so the shimmer sweep appears coherent across the UI.

class Skeleton extends StatefulWidget {
  final Widget child;
  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (_, child) {
        // x sweeps from −0.6 to 1.6, so the highlight spends the full
        // duration travelling across the widest possible screen.
        final x = _ctrl.value * 2.2 - 0.6;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFDDE3EC), // base slate
              Color(0xFFF0F4FA), // highlight
              Color(0xFFDDE3EC), // base slate
            ],
            stops: [
              (x - 0.3).clamp(0.0, 1.0),
              x.clamp(0.0, 1.0),
              (x + 0.3).clamp(0.0, 1.0),
            ],
          ).createShader(bounds),
          child: child!,
        );
      },
    );
  }
}

// ─── Primitive building blocks ────────────────────────────────────────────────

/// Rounded white placeholder rectangle — tinted by the parent [Skeleton].
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Short horizontal line (text placeholder).
class SkeletonLine extends StatelessWidget {
  final double? width;
  const SkeletonLine({super.key, this.width});

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: 12, radius: 4);
}

// ─── Composite components ─────────────────────────────────────────────────────

/// KPI card with left accent bar, large number, and label.
class SkeletonKpiCard extends StatelessWidget {
  const SkeletonKpiCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Fixed height gives Row(crossAxisAlignment.stretch) a bounded constraint,
    // which is required for the left accent strip to stretch to full card height.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: const Color(0xFFE8EDF3)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: const Color(0xFFDDE3EC)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonLine(width: 90),
                    SizedBox(height: 10),
                    SkeletonBox(width: 64, height: 24),
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

/// Table row with [cells] evenly-spaced short lines.
class SkeletonTableRow extends StatelessWidget {
  final int cells;
  const SkeletonTableRow({super.key, this.cells = 5});

  // Staggered widths to look like real data
  static const _w = [80.0, 120.0, 90.0, 60.0, 100.0, 70.0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          for (int i = 0; i < cells; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SkeletonLine(width: _w[i % _w.length]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card tile with circle avatar + two lines + trailing chip (list item).
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          SkeletonBox(width: 38, height: 38, radius: 19),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(width: 150),
                SizedBox(height: 7),
                SkeletonLine(width: 95),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 64, height: 24, radius: 6),
        ],
      ),
    );
  }
}

/// POS menu card (emoji block + name + price).
class SkeletonMenuTile extends StatelessWidget {
  const SkeletonMenuTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonBox(width: 48, height: 48, radius: 8),
          SizedBox(height: 10),
          SkeletonLine(width: 64),
          SizedBox(height: 7),
          SkeletonBox(width: 44, height: 14, radius: 4),
        ],
      ),
    );
  }
}

// ─── Full-screen skeleton layouts ─────────────────────────────────────────────

/// Dashboard: header + 4 KPI cards + occupancy bar + recent list.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        color: AppTheme.pageBg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 26),
                      SizedBox(height: 8),
                      SkeletonLine(width: 220),
                    ],
                  ),
                  SkeletonLine(width: 130),
                ],
              ),
              const SizedBox(height: 32),
              // 4 KPI cards
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 48) / 4;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                      4, (_) => SizedBox(width: w, child: const SkeletonKpiCard())),
                );
              }),
              const SizedBox(height: 32),
              // Occupancy bar card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: 140),
                    SizedBox(height: 16),
                    SkeletonBox(height: 28, radius: 8),
                    SizedBox(height: 10),
                    SkeletonLine(width: 180),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Recent check-ins card
              Container(
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonLine(width: 160),
                          SkeletonBox(width: 80, height: 28, radius: 8),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    for (int i = 0; i < 6; i++) ...[
                      const SkeletonListTile(),
                      if (i < 5) const Divider(height: 1, indent: 72),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic table/list screen: header bar + scrollable table with rows.
class TableListSkeleton extends StatelessWidget {
  final int rowCount;
  final int cellCount;
  const TableListSkeleton({super.key, this.rowCount = 8, this.cellCount = 5});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        color: AppTheme.pageBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page header bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.isMobile(context) ? 16 : 32,
                  vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 180, height: 24),
                  Row(children: [
                    SkeletonBox(width: 110, height: 36, radius: 10),
                    SizedBox(width: 10),
                    SkeletonBox(width: 90, height: 36, radius: 10),
                  ]),
                ],
              ),
            ),
            // Search / filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
              child: Row(
                children: const [
                  Expanded(child: SkeletonBox(height: 40, radius: 10)),
                  SizedBox(width: 12),
                  SkeletonBox(width: 130, height: 40, radius: 10),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Table card
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.isMobile(context) ? 16 : 32),
                child: Container(
                  decoration: AppTheme.cardDecoration,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Column headers
                      Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            for (int i = 0; i < cellCount; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(
                                child: SkeletonLine(
                                    width: [60.0, 80.0, 70.0, 50.0, 80.0]
                                        [i % 5]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: rowCount,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, __) =>
                              SkeletonTableRow(cells: cellCount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// POS: header + category pills + menu grid + blank cart panel.
class PosMenuSkeleton extends StatelessWidget {
  const PosMenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ColoredBox(
        color: const Color(0xFFF1F5F9),
        child: Row(
          children: [
            // Left: menu area
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  // Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBox(width: 180, height: 24),
                        SkeletonLine(width: 130),
                      ],
                    ),
                  ),
                  // Category pills bar
                  Container(
                    height: 58,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Row(
                      children: const [
                        SkeletonBox(width: 56, height: 32, radius: 16),
                        SizedBox(width: 8),
                        SkeletonBox(width: 80, height: 32, radius: 16),
                        SizedBox(width: 8),
                        SkeletonBox(width: 68, height: 32, radius: 16),
                        SizedBox(width: 8),
                        SkeletonBox(width: 90, height: 32, radius: 16),
                        SizedBox(width: 8),
                        SkeletonBox(width: 72, height: 32, radius: 16),
                      ],
                    ),
                  ),
                  // Menu grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(20),
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: 12,
                      itemBuilder: (_, __) => const SkeletonMenuTile(),
                    ),
                  ),
                ],
              ),
            ),
            // Right: cart panel
            Container(
              width: 370,
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SkeletonBox(width: 140, height: 20),
                            SkeletonBox(width: 60, height: 24, radius: 8),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: SkeletonBox(height: 40, radius: 8)),
                          SizedBox(width: 8),
                          Expanded(child: SkeletonBox(height: 40, radius: 8)),
                        ]),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const Expanded(
                    child: Center(
                      child: SkeletonBox(
                          width: 56, height: 56, radius: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Financials: header + 4 KPI cards + bar chart placeholder + table.
class KpiTableSkeleton extends StatelessWidget {
  const KpiTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        color: AppTheme.pageBg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(width: 170, height: 26),
                  Row(children: [
                    SkeletonBox(width: 110, height: 36, radius: 10),
                    SizedBox(width: 10),
                    SkeletonBox(width: 90, height: 36, radius: 10),
                  ]),
                ],
              ),
              const SizedBox(height: 32),
              // 4 KPI cards
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - 48) / 4;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                      4, (_) => SizedBox(width: w, child: const SkeletonKpiCard())),
                );
              }),
              const SizedBox(height: 32),
              // Bar chart card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLine(width: 200),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 160,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          14,
                          (i) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: SkeletonBox(
                                // staggered bar heights
                                height: 40 + (i % 7) * 18.0,
                                radius: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Table card
              Container(
                decoration: AppTheme.cardDecoration,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: const [
                          Expanded(child: SkeletonLine(width: 60)),
                          SizedBox(width: 16),
                          Expanded(child: SkeletonLine(width: 80)),
                          SizedBox(width: 16),
                          Expanded(child: SkeletonLine(width: 70)),
                          SizedBox(width: 16),
                          Expanded(child: SkeletonLine(width: 60)),
                          SizedBox(width: 16),
                          Expanded(child: SkeletonLine(width: 50)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    for (int i = 0; i < 7; i++) ...[
                      const SkeletonTableRow(cells: 5),
                      if (i < 6) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
