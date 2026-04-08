import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/plan_service.dart';
import '../services/lead_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFFFFFFF); // white base
  static const surface   = Color(0xFFF8FAFC); // very light grey
  static const card      = Color(0xFFFFFFFF); // white cards
  static const border    = Color(0xFFE2E8F0); // soft border
  static const gold      = Color(0xFFD4A853);
  static const goldLight = Color(0xFFEDD07A);
  static const text      = Color(0xFF0F172A); // near-black
  static const subtext   = Color(0xFF64748B); // medium grey
  static const muted     = Color(0xFF94A3B8); // light grey
}

// ─── Landing screen ───────────────────────────────────────────────────────────
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollCtrl = ScrollController();
  bool _navSolid = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final solid = _scrollCtrl.offset > 40;
      if (solid != _navSolid) setState(() => _navSolid = solid);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                const SizedBox(height: 100), // space for fixed nav
                _HeroSection(isMobile: isMobile),
                _FeaturesSection(isMobile: isMobile),
                _PricingSection(isMobile: isMobile),
                _CtaSection(isMobile: isMobile),
                _Footer(isMobile: isMobile),
              ],
            ),
          ),
          // ── Fixed navigation bar ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _NavBar(solid: _navSolid, isMobile: isMobile),
          ),
        ],
      ),
    );
  }
}

// ─── Navigation bar ───────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final bool solid;
  final bool isMobile;
  const _NavBar({required this.solid, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 100,
      decoration: BoxDecoration(
        color: solid ? Colors.white.withAlpha(242) : Colors.transparent,
        border: solid
            ? const Border(bottom: BorderSide(color: _C.border, width: 1))
            : null,
        boxShadow: solid
            ? [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 16)]
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48),
      child: Row(
        children: [
          // Logo only — no text
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.gold.withAlpha(100),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/hotrest_logo.png',
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign In',
                  style: TextStyle(color: _C.subtext, fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          _GoldButton(
            label: 'Get Started',
            small: isMobile,
            onTap: () => context.go('/signup'),
          ),
        ],
      ),
    );
  }
}

// ─── Hero section ─────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final bool isMobile;
  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [
            Color(0xFFFFF8E8), // warm cream glow behind logo
            Color(0xFFF8FAFC), // cool light grey mid
            Color(0xFFFFFFFF), // pure white edges
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Hero brand logo
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.gold.withAlpha(90),
                  blurRadius: 50,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: _C.gold.withAlpha(30),
                  blurRadius: 100,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/hotrest_logo.png',
              width: isMobile ? 220 : 300,
              height: isMobile ? 220 : 300,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hotel & Restaurant Management Platform',
            style: TextStyle(
              color: _C.subtext,
              fontSize: isMobile ? 15 : 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 48),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _C.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.gold.withAlpha(60)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: _C.gold, size: 14),
                SizedBox(width: 6),
                Text(
                  'All-in-one Hotel & Restaurant Management',
                  style: TextStyle(color: _C.gold, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Headline
          Text(
            'Run Your Property\nLike a Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 36 : 60,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Text(
              'Manage bookings, rooms, restaurant orders, staff schedules, '
              'and guest experiences — all from one beautiful dashboard. '
              'White-label ready for hotel chains.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _C.subtext,
                fontSize: 17,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // CTA buttons
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _GoldButton(
                label: 'Start Free Trial',
                onTap: () => context.go('/signup'),
                large: true,
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded, size: 18, color: _C.subtext),
                label: const Text('Sign In', style: TextStyle(color: _C.subtext, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.border),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          // Dashboard preview mockup
          _DashboardMockup(isMobile: isMobile),
        ],
      ),
    );
  }
}

// ─── Fake dashboard preview ───────────────────────────────────────────────────
class _DashboardMockup extends StatelessWidget {
  final bool isMobile;
  const _DashboardMockup({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(color: _C.gold.withAlpha(40), blurRadius: 40, spreadRadius: 2),
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 24),
        ],
      ),
      child: Column(
        children: [
          // Browser chrome
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: _C.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _dot(const Color(0xFFEF4444)),
              const SizedBox(width: 6),
              _dot(const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              _dot(const Color(0xFF22C55E)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const Text('app.hotrest.io/app',
                      style: TextStyle(color: _C.muted, fontSize: 11)),
                ),
              ),
            ]),
          ),
          // Stat cards row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatCard(label: 'Occupancy', value: '87%', icon: Icons.king_bed_rounded, color: const Color(0xFF22C55E)),
                    const SizedBox(width: 12),
                    _StatCard(label: "Today's Revenue", value: '\$4,280', icon: Icons.attach_money_rounded, color: _C.gold),
                    const SizedBox(width: 12),
                    if (!isMobile) _StatCard(label: 'Active Orders', value: '12', icon: Icons.restaurant_rounded, color: const Color(0xFFF97316)),
                    if (!isMobile) const SizedBox(width: 12),
                    if (!isMobile) _StatCard(label: 'Check-Ins Today', value: '8', icon: Icons.how_to_reg_rounded, color: const Color(0xFF3B82F6)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _MockChart()),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: _MockRoomGrid()),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: const TextStyle(color: _C.subtext, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _MockChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bars = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.75];
    return Container(
      height: 80,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((h) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FractionallySizedBox(
            heightFactor: h,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: _C.gold.withAlpha(180),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ))).toList(),
      ),
    );
  }
}

class _MockRoomGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final statuses = ['occ', 'occ', 'avail', 'occ', 'maint', 'avail', 'occ', 'avail', 'occ'];
    return Container(
      height: 80,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Wrap(
        spacing: 4, runSpacing: 4,
        children: statuses.map((s) => Container(
          width: 24, height: 18,
          decoration: BoxDecoration(
            color: s == 'occ'
                ? const Color(0xFFEF4444).withAlpha(160)
                : s == 'avail'
                    ? const Color(0xFF22C55E).withAlpha(160)
                    : const Color(0xFFF59E0B).withAlpha(160),
            borderRadius: BorderRadius.circular(4),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── Features section ─────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  final bool isMobile;
  const _FeaturesSection({required this.isMobile});

  static const _features = [
    (
      icon: Icons.king_bed_rounded,
      color: Color(0xFF3B82F6),
      title: 'Hotel Management',
      bullets: [
        'Room setup, types & availability',
        'Reservations & walk-in check-in/out',
        'Folio billing & payment tracking',
        'Housekeeping task management',
        'Occupancy & room status overview',
      ],
    ),
    (
      icon: Icons.point_of_sale_rounded,
      color: Color(0xFFF97316),
      title: 'Restaurant POS',
      bullets: [
        'Table-side & counter ordering',
        'Live kitchen display system (KDS)',
        'Menu & category management',
        'Split bills & multiple payment modes',
        'Real-time sales analytics',
      ],
    ),
    (
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFF22C55E),
      title: 'Guest Portal',
      bullets: [
        'QR-based self check-in & check-out',
        'Room service ordering via phone',
        'Digital menus — no app download',
        'Booking lookup & stay details',
        'Direct messaging with front desk',
      ],
    ),
    (
      icon: Icons.palette_rounded,
      color: Color(0xFFD4A853),
      title: 'White-Label Ready',
      bullets: [
        'Custom brand colors & logo',
        'Property name on all guest screens',
        'Branded QR codes & menus',
        'No HotRest branding visible to guests',
        'Multi-property brand profiles',
      ],
    ),
    (
      icon: Icons.people_alt_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Staff & Shifts',
      bullets: [
        'Role-based access control',
        'Shift scheduling & clock-in/out',
        'Time tracking & attendance logs',
        'Staff invite via unique code',
        'Per-property permission management',
      ],
    ),
    (
      icon: Icons.analytics_rounded,
      color: Color(0xFF06B6D4),
      title: 'Financial Reports',
      bullets: [
        'Daily revenue & expense summaries',
        'Invoice & folio export to PDF',
        'Occupancy rate tracking',
        'Restaurant sales breakdown',
        'Date-range custom reporting',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          _SectionLabel(label: 'FEATURES'),
          const SizedBox(height: 16),
          Text(
            'Everything You Need to\nRun a Great Property',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 28 : 42,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Purpose-built for hotels and restaurants — no bloated ERP, just the tools you need.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.subtext, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 56),
          // Grid
          LayoutBuilder(builder: (_, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: constraints.maxWidth > 700 ? 1.9 : 1.55,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _features.map((f) =>
                _FeatureCard(icon: f.icon, color: f.color, title: f.title, bullets: f.bullets),
              ).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> bullets;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        ...bullets.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(b, style: const TextStyle(color: _C.subtext, fontSize: 12.5, height: 1.45)),
              ),
            ],
          ),
        )),
      ]),
    );
  }
}

// ─── Pricing section (dynamic from DB) ───────────────────────────────────────
class _PricingSection extends StatefulWidget {
  final bool isMobile;
  const _PricingSection({required this.isMobile});

  @override
  State<_PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<_PricingSection> {
  late Future<List<PlanModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = PlanService().getActivePlans();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 24 : 80,
        vertical: widget.isMobile ? 60 : 100,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F4FF), Color(0xFFF8FAFC)],
        ),
      ),
      child: Column(
        children: [
          _SectionLabel(label: 'PRICING'),
          const SizedBox(height: 16),
          Text(
            'Simple, Transparent Pricing',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: widget.isMobile ? 28 : 42,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start free. No credit card required. Upgrade when you\'re ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.subtext, fontSize: 16),
          ),
          const SizedBox(height: 56),
          FutureBuilder<List<PlanModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final plans = snapshot.data ?? [];
              if (plans.isEmpty) return const SizedBox.shrink();
              return LayoutBuilder(builder: (_, constraints) {
                final wide = constraints.maxWidth > 800;
                if (wide) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < plans.length; i++) ...[
                          if (i > 0) const SizedBox(width: 16),
                          Expanded(child: _PricingCard(plan: plans[i])),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < plans.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _PricingCard(plan: plans[i]),
                    ],
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final PlanModel plan;
  const _PricingCard({required this.plan});

  /// Build feature bullets from plan limits.
  List<String> get _features {
    String limit(int v) => v == -1 ? 'Unlimited' : v.toString();
    return [
      '${limit(plan.maxProperties)} ${plan.maxProperties == 1 ? 'property' : 'properties'}',
      '${limit(plan.maxRooms)} rooms',
      '${limit(plan.maxUsers)} staff accounts',
      '${limit(plan.maxTables)} restaurant tables',
      'Hotel + Restaurant modules',
      'Guest portal (QR check-in & menu)',
      if (plan.slug != 'free') 'White-label branding',
      if (plan.isCustomPrice) 'Dedicated account manager',
      if (plan.isCustomPrice) 'SLA & uptime guarantee',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = plan.isHighlighted;
    final priceStr = plan.isCustomPrice
        ? 'Custom'
        : plan.priceMonthly == 0
            ? 'Free'
            : '\$${plan.priceMonthly.toStringAsFixed(0)}';
    final isEnterprise = plan.isCustomPrice;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: highlighted ? _C.gold.withAlpha(12) : _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? _C.gold.withAlpha(120) : _C.border,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: _C.gold.withAlpha(25), blurRadius: 40, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Plan name + badge
          Row(children: [
            Text(plan.name,
                style: TextStyle(
                  color: highlighted ? _C.gold : _C.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            if (highlighted) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Most Popular',
                    style: TextStyle(
                      color: _C.bg,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          // Price
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(priceStr,
                style: TextStyle(
                  color: highlighted ? _C.goldLight : _C.text,
                  fontSize: isEnterprise ? 28 : 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            if (!isEnterprise && plan.priceMonthly > 0) ...[
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('/ month', style: TextStyle(color: _C.subtext, fontSize: 14)),
              ),
            ],
          ]),
          const SizedBox(height: 24),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 20),
          // Feature bullets
          ..._features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.check_circle_rounded,
                  size: 16,
                  color: highlighted ? _C.gold : const Color(0xFF22C55E)),
              const SizedBox(width: 10),
              Expanded(child: Text(f, style: const TextStyle(color: _C.subtext, fontSize: 13))),
            ]),
          )),
          const Spacer(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: highlighted
                ? ElevatedButton(
                    onPressed: () => context.go('/signup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.gold,
                      foregroundColor: _C.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Get Started',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  )
                : OutlinedButton(
                    onPressed: () {
                      if (isEnterprise) {
                        showDialog(
                          context: context,
                          builder: (_) => const _EnterpriseContactDialog(),
                        );
                      } else {
                        context.go('/signup');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.text,
                      side: const BorderSide(color: _C.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isEnterprise ? 'Contact Sales' : 'Get Started',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── CTA section ──────────────────────────────────────────────────────────────
class _CtaSection extends StatelessWidget {
  final bool isMobile;
  const _CtaSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 80,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 28 : 60,
            vertical: isMobile ? 40 : 60,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8E8),
                Color(0xFFF8FAFC),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.gold.withAlpha(100)),
            boxShadow: [
              BoxShadow(color: _C.gold.withAlpha(30), blurRadius: 40, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _C.gold.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.gold.withAlpha(80), width: 2),
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset('assets/images/hotrest_logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 24),
              Text(
                'Ready to transform your property?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.text,
                  fontSize: isMobile ? 24 : 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Join hundreds of properties already using HotRest.\nNo credit card required — start in minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.subtext, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              _GoldButton(
                label: 'Create Free Account',
                large: true,
                onTap: () => context.go('/signup'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Already have an account? Sign in →',
                  style: TextStyle(color: _C.subtext, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final bool isMobile;
  const _Footer({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 32,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _logoMark(),
                const SizedBox(height: 12),
                _tagline(),
                const SizedBox(height: 16),
                _links(context),
              ],
            )
          : Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _logoMark(),
                  const SizedBox(height: 8),
                  _tagline(),
                ]),
                const Spacer(),
                _links(context),
              ],
            ),
    );
  }

  Widget _logoMark() => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _C.gold.withAlpha(80), blurRadius: 12, spreadRadius: 1)],
      ),
      child: Image.asset('assets/images/hotrest_logo.png', width: 40, height: 40, fit: BoxFit.contain),
    ),
    const SizedBox(width: 10),
    ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_C.goldLight, _C.gold],
      ).createShader(bounds),
      child: const Text('HotRest',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    ),
  ]);

  Widget _tagline() => const Text(
    '© 2025 HotRest. All rights reserved.',
    style: TextStyle(color: _C.subtext, fontSize: 13),
  );

  Widget _links(BuildContext context) => Wrap(
    spacing: 24,
    children: [
      _footerLink('Sign In', () => context.go('/login')),
      _footerLink('Get Started', () => context.go('/signup')),
    ],
  );

  Widget _footerLink(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
    child: Text(label, style: const TextStyle(color: _C.muted, fontSize: 13)),
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _C.gold.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold.withAlpha(50)),
      ),
      child: Text(label,
          style: const TextStyle(
            color: _C.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          )),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool large;
  final bool small;
  const _GoldButton({
    required this.label,
    required this.onTap,
    this.large = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.gold,
        foregroundColor: _C.bg,
        padding: EdgeInsets.symmetric(
          horizontal: small ? 16 : large ? 36 : 24,
          vertical: small ? 10 : large ? 18 : 14,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(small ? 8 : 12)),
        elevation: 0,
      ),
      child: Text(label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: small ? 13 : large ? 16 : 14,
          )),
    );
  }
}

// ─── Enterprise Contact Dialog ────────────────────────────────────────────────

class _EnterpriseContactDialog extends StatefulWidget {
  const _EnterpriseContactDialog();

  @override
  State<_EnterpriseContactDialog> createState() => _EnterpriseContactDialogState();
}

class _EnterpriseContactDialogState extends State<_EnterpriseContactDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _name      = TextEditingController();
  final _company   = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();
  final _message   = TextEditingController();
  final _propCount = TextEditingController();
  final _service   = LeadService();
  bool _submitting = false;
  bool _submitted  = false;

  @override
  void dispose() {
    _name.dispose(); _company.dispose(); _email.dispose();
    _phone.dispose(); _message.dispose(); _propCount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _service.submitLead(
        name:          _name.text.trim(),
        company:       _company.text.trim(),
        email:         _email.text.trim(),
        phone:         _phone.text.trim(),
        propertyCount: int.tryParse(_propCount.text.trim()),
        message:       _message.text.trim(),
      );
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 36),
      ),
      const SizedBox(height: 20),
      const Text('Request Received!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.text)),
      const SizedBox(height: 10),
      const Text(
        'Thank you for reaching out. Our team will contact you within 1–2 business days to discuss your requirements.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _C.subtext, fontSize: 14, height: 1.5),
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.gold,
            foregroundColor: _C.bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  );

  Widget _buildForm() => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _C.gold.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_rounded, color: _C.gold, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Enterprise Enquiry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.text)),
              Text('We\'ll get back to you within 1–2 business days.',
                  style: TextStyle(fontSize: 12, color: _C.subtext)),
            ]),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: _C.subtext),
            splashRadius: 20,
          ),
        ]),
        const SizedBox(height: 24),
        const Divider(color: _C.border),
        const SizedBox(height: 20),

        // Row: Name + Company
        Row(children: [
          Expanded(child: _field(_name,  'Full Name *', validator: _required)),
          const SizedBox(width: 12),
          Expanded(child: _field(_company, 'Company Name *', validator: _required)),
        ]),
        const SizedBox(height: 12),

        // Row: Email + Phone
        Row(children: [
          Expanded(child: _field(_email, 'Work Email *',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              })),
          const SizedBox(width: 12),
          Expanded(child: _field(_phone, 'Phone (optional)',
              keyboardType: TextInputType.phone)),
        ]),
        const SizedBox(height: 12),

        // Properties
        _field(_propCount, 'Estimated number of properties',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 12),

        // Message
        _field(_message, 'Tell us about your requirements (optional)',
            maxLines: 4),
        const SizedBox(height: 24),

        // Submit
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.gold,
              foregroundColor: _C.bg,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.bg))
                : const Text('Send Enquiry',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    ),
  );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 13, color: _C.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _C.muted, fontSize: 13),
          filled: true,
          fillColor: _C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.gold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      );
}
