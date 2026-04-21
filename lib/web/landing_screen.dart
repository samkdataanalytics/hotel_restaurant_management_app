import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/plan_service.dart';
import '../services/lead_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFFFFFFF);
  static const surface   = Color(0xFFF8FAFC);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE2E8F0);
  static const gold      = Color(0xFFD4A853);
  static const goldLight = Color(0xFFEDD07A);
  static const text      = Color(0xFF0F172A);
  static const subtext   = Color(0xFF64748B);
  static const muted     = Color(0xFF94A3B8);
  static const dark      = Color(0xFF0F172A);
  static const darkCard  = Color(0xFF1E293B);
}

// ─── Landing screen ───────────────────────────────────────────────────────────
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollCtrl  = ScrollController();
  final _featuresKey = GlobalKey();
  final _pricingKey  = GlobalKey();
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

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                const SizedBox(height: 100),
                _HeroSection(isMobile: isMobile),
                SizedBox(key: _featuresKey, child: _FeaturesSection(isMobile: isMobile)),
                SizedBox(key: _pricingKey, child: _PricingSection(isMobile: isMobile)),
                _CtaSection(isMobile: isMobile),
                _Footer(isMobile: isMobile),
              ],
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: _NavBar(
              solid: _navSolid,
              isMobile: isMobile,
              onFeatures: () => _scrollTo(_featuresKey),
              onPricing:  () => _scrollTo(_pricingKey),
            ),
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
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  const _NavBar({required this.solid, required this.isMobile, required this.onFeatures, required this.onPricing});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 100,
      decoration: BoxDecoration(
        color: solid ? Colors.white.withAlpha(248) : Colors.transparent,
        border: solid
            ? const Border(bottom: BorderSide(color: _C.border, width: 1))
            : null,
        boxShadow: solid
            ? [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 20)]
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60),
      child: Row(
        children: [
          // Animated nav logo
          const _AnimatedLogo(size: 72),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_C.goldLight, _C.gold],
              ).createShader(bounds),
              child: const Text('HotRest',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ),
          ],
          const Spacer(),
          if (!isMobile) ...[
            _NavLink(label: 'Features', onTap: onFeatures),
            _NavLink(label: 'Pricing',  onTap: onPricing),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Sign In',
                  style: TextStyle(color: _C.subtext, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
          ],
          _GoldButton(
            label: 'Get Started Free',
            small: isMobile,
            onTap: () => context.go('/signup'),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap});
  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: TextButton(
        onPressed: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            color: _hovered ? _C.gold : _C.subtext,
            fontSize: 14,
            fontWeight: _hovered ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─── Animated logo ────────────────────────────────────────────────────────────
class _AnimatedLogo extends StatefulWidget {
  final double size;
  const _AnimatedLogo({required this.size});
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, __) {
        final blurOuter = 60 + _pulse.value * 60;   // 60 → 120
        final blurInner = 20 + _pulse.value * 30;   // 20 → 50
        final spreadOuter = 8 + _pulse.value * 14;  //  8 → 22
        final innerAlpha = (60 + _pulse.value * 100).round().clamp(0, 255); // 60 → 160
        final outerAlpha = (20 + _pulse.value * 50).round().clamp(0, 255);  // 20 → 70

        return ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _C.gold.withAlpha(innerAlpha),
                  blurRadius: blurInner,
                  spreadRadius: spreadOuter / 2,
                ),
                BoxShadow(
                  color: _C.goldLight.withAlpha(outerAlpha),
                  blurRadius: blurOuter,
                  spreadRadius: spreadOuter,
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/hotrest_logo.webp',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
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
          radius: 1.2,
          colors: [
            Color(0xFFFFF8E8),
            Color(0xFFF8FAFC),
            Color(0xFFFFFFFF),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Animated brand logo
          _AnimatedLogo(size: isMobile ? 180 : 260),
          const SizedBox(height: 32),
          // Trust badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: _C.gold.withAlpha(18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _C.gold.withAlpha(60)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: _C.gold, size: 14),
                SizedBox(width: 7),
                Text(
                  'Trusted by 500+ Properties Worldwide',
                  style: TextStyle(
                    color: _C.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // Headline
          Text(
            'The All-in-One Platform\nfor Modern Hospitality',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 34 : 62,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Manage bookings, rooms, restaurant orders, staff schedules, '
              'and guest experiences — all from one beautiful dashboard. '
              'Built for hotels and restaurants that demand excellence.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _C.subtext,
                fontSize: isMobile ? 15 : 17,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 36),
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
          const SizedBox(height: 14),
          // No credit card note
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: _C.muted),
              SizedBox(width: 5),
              Text(
                'No credit card required · Free forever on Starter plan',
                style: TextStyle(color: _C.muted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 64),
          // Dashboard preview mockup
          _DashboardMockup(isMobile: isMobile),
        ],
      ),
    );
  }
}

// ─── Stats strip ──────────────────────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final bool isMobile;
  const _StatsStrip({required this.isMobile});

  static const _stats = [
    (value: '500+',   label: 'Properties'),
    (value: '50K+',   label: 'Bookings Managed'),
    (value: '99.9%',  label: 'Uptime SLA'),
    (value: '4.9★',   label: 'Average Rating'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: 40,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: isMobile
          ? Wrap(
              spacing: 32,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: _stats.map((s) => _StatItem(value: s.value, label: s.label)).toList(),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _stats.map((s) => _StatItem(value: s.value, label: s.label)).toList(),
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_C.goldLight, _C.gold],
          ).createShader(bounds),
          child: Text(value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              )),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color: Colors.white.withAlpha(160),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            )),
      ],
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
          BoxShadow(color: _C.gold.withAlpha(45), blurRadius: 50, spreadRadius: 4),
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 30),
        ],
      ),
      child: Column(
        children: [
          // Browser chrome
          Container(
            height: 40,
            decoration: const BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: _C.border)),
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
                  child: const Text('app.hotrest.io/app/dashboard',
                      style: TextStyle(color: _C.muted, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('● Live', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Dashboard content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top bar
                Row(
                  children: [
                    const Text('Good morning, Alex 👋',
                        style: TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.gold.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.gold.withAlpha(60)),
                      ),
                      child: const Text('Grand Ocean Hotel', style: TextStyle(color: _C.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const _StatCard(label: 'Occupancy', value: '87%', icon: Icons.king_bed_rounded, color: Color(0xFF22C55E), trend: '+4%'),
                    const SizedBox(width: 10),
                    const _StatCard(label: "Today's Revenue", value: '\$4,280', icon: Icons.attach_money_rounded, color: _C.gold, trend: '+12%'),
                    const SizedBox(width: 10),
                    if (!isMobile) const _StatCard(label: 'Active Orders', value: '12', icon: Icons.restaurant_rounded, color: Color(0xFFF97316), trend: '↑ Busy'),
                    if (!isMobile) const SizedBox(width: 10),
                    if (!isMobile) const _StatCard(label: 'Check-Ins Today', value: '8', icon: Icons.how_to_reg_rounded, color: Color(0xFF3B82F6), trend: '3 pending'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _MockChart()),
                  const SizedBox(width: 10),
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
  final String? trend;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.trend});

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
          Row(children: [
            Icon(icon, color: color, size: 16),
            const Spacer(),
            if (trend != null)
              Text(trend!, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 18)),
          Text(label, style: const TextStyle(color: _C.subtext, fontSize: 9.5)),
        ]),
      ),
    );
  }
}

class _MockChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bars = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.75];
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      height: 90,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (i) => Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FractionallySizedBox(
                  heightFactor: bars[i],
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_C.goldLight.withAlpha(200), _C.gold.withAlpha(220)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ))),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: List.generate(labels.length, (i) => Expanded(
              child: Text(labels[i], textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.muted, fontSize: 7.5)),
            )),
          ),
        ],
      ),
    );
  }
}

class _MockRoomGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rooms = [
      ('101', 'occ'), ('102', 'occ'), ('103', 'avail'),
      ('201', 'occ'), ('202', 'maint'), ('203', 'avail'),
      ('301', 'occ'), ('302', 'avail'), ('303', 'occ'),
    ];
    return Container(
      height: 90,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Room Status', style: TextStyle(color: _C.subtext, fontSize: 8.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: rooms.map((r) => Tooltip(
                message: 'Room ${r.$1}: ${r.$2 == 'occ' ? 'Occupied' : r.$2 == 'avail' ? 'Available' : 'Maintenance'}',
                child: Container(
                  width: 28, height: 18,
                  decoration: BoxDecoration(
                    color: r.$2 == 'occ'
                        ? const Color(0xFFEF4444).withAlpha(150)
                        : r.$2 == 'avail'
                            ? const Color(0xFF22C55E).withAlpha(150)
                            : const Color(0xFFF59E0B).withAlpha(150),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: Text(r.$1, style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w700)),
                ),
              )).toList(),
            ),
          ),
        ],
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
          const _SectionLabel(label: 'FEATURES'),
          const SizedBox(height: 16),
          Text(
            'Everything You Need to\nRun a Great Property',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 28 : 44,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: const Text(
              'Purpose-built for hotels and restaurants — not a bloated ERP. '
              'Every tool you need, none you don\'t.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.subtext, fontSize: 15.5, height: 1.55),
            ),
          ),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (_, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: constraints.maxWidth > 700 ? 1.85 : 1.5,
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

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> bullets;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.bullets});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withAlpha(8) : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? widget.color.withAlpha(80) : _C.border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withAlpha(20), blurRadius: 20, spreadRadius: 2)]
              : null,
        ),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color.withAlpha(22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(widget.title, style: const TextStyle(color: _C.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...widget.bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5.5),
                    child: Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
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
        ),
      ),
    );
  }
}

// ─── Testimonials section ─────────────────────────────────────────────────────
class _TestimonialsSection extends StatelessWidget {
  final bool isMobile;
  const _TestimonialsSection({required this.isMobile});

  static const _testimonials = [
    (
      quote: 'HotRest cut our front-desk workload in half. Check-in used to take 5 minutes per guest — now guests self-check in via QR. The staff scheduling alone is worth every cent.',
      name:  'Sarah Mitchell',
      role:  'General Manager',
      hotel: 'The Riverview Boutique Hotel',
      initials: 'SM',
      color: Color(0xFF3B82F6),
    ),
    (
      quote: 'We run 3 properties and the multi-property dashboard is a game-changer. I can see revenue, occupancy and active restaurant orders for all locations in one screen. Incredible.',
      name:  'James Okonkwo',
      role:  'Director of Operations',
      hotel: 'Okonkwo Hospitality Group',
      initials: 'JO',
      color: Color(0xFFD4A853),
    ),
    (
      quote: 'Switching from our old PMS was painless. The onboarding took less than 20 minutes, and the white-label guest portal means our branding is front and center — not some software company\'s logo.',
      name:  'Priya Ramaswamy',
      role:  'Owner',
      hotel: 'Serenity Suites & Restaurant',
      initials: 'PR',
      color: Color(0xFF22C55E),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
        ),
      ),
      child: Column(
        children: [
          const _SectionLabel(label: 'TESTIMONIALS'),
          const SizedBox(height: 16),
          Text(
            'Loved by Hospitality\nProfessionals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 28 : 44,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (_, constraints) {
            final wide = constraints.maxWidth > 700;
            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < _testimonials.length; i++) ...[
                      if (i > 0) const SizedBox(width: 20),
                      Expanded(child: _TestimonialCard(
                        quote: _testimonials[i].quote,
                        name: _testimonials[i].name,
                        role: _testimonials[i].role,
                        hotel: _testimonials[i].hotel,
                        initials: _testimonials[i].initials,
                        color: _testimonials[i].color,
                      )),
                    ],
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < _testimonials.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  _TestimonialCard(
                    quote: _testimonials[i].quote,
                    name: _testimonials[i].name,
                    role: _testimonials[i].role,
                    hotel: _testimonials[i].hotel,
                    initials: _testimonials[i].initials,
                    color: _testimonials[i].color,
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String quote, name, role, hotel, initials;
  final Color color;
  const _TestimonialCard({
    required this.quote, required this.name, required this.role,
    required this.hotel, required this.initials, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars
          Row(
            children: List.generate(5, (_) => const Icon(Icons.star_rounded, color: _C.gold, size: 16)),
          ),
          const SizedBox(height: 16),
          // Quote
          Text(
            '"$quote"',
            style: const TextStyle(
              color: _C.text,
              fontSize: 13.5,
              height: 1.65,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 20),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 16),
          // Author
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(60), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('$role · $hotel',
                        style: const TextStyle(color: _C.subtext, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
          const _SectionLabel(label: 'PRICING'),
          const SizedBox(height: 16),
          Text(
            'Simple, Transparent Pricing',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: widget.isMobile ? 28 : 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start free. No credit card required. Upgrade when you\'re ready.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.subtext, fontSize: 15.5),
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
            ? [BoxShadow(color: _C.gold.withAlpha(30), blurRadius: 40, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
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
                    style: TextStyle(color: _C.bg, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          const SizedBox(height: 20),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _C.gold.withAlpha(25),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _C.gold.withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: _C.gold, size: 14),
                    SizedBox(width: 7),
                    Text(
                      'Get started in under 5 minutes',
                      style: TextStyle(color: _C.gold, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Ready to transform\nyour property?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 28 : 42,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Join hundreds of hospitality teams already running smarter with HotRest.\nNo credit card required — start in minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _GoldButton(
                    label: 'Create Free Account',
                    large: true,
                    onTap: () => context.go('/signup'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Trust row
              const Wrap(
                spacing: 24,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _TrustChip(icon: Icons.lock_outline_rounded, label: 'SOC 2 Compliant'),
                  _TrustChip(icon: Icons.shield_outlined, label: 'GDPR Ready'),
                  _TrustChip(icon: Icons.support_agent_rounded, label: '24/7 Support'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withAlpha(100), size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 12)),
      ],
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
        vertical: 48,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _logoMark(),
                const SizedBox(height: 8),
                _tagline(),
                const SizedBox(height: 28),
                _links(context),
                const SizedBox(height: 28),
                const Divider(color: Color(0xFF1E293B), height: 1),
                const SizedBox(height: 16),
                _copyright(),
              ],
            )
          : Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand column
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _logoMark(),
                          const SizedBox(height: 12),
                          Text(
                            'The all-in-one hotel & restaurant management platform for modern hospitality teams.',
                            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Product links
                    _FooterColumn(title: 'Product', items: [
                      const _FooterItem('Features', null),
                      const _FooterItem('Pricing', null),
                      _FooterItem('Sign In', () => context.go('/login')),
                      _FooterItem('Get Started', () => context.go('/signup')),
                    ]),
                    const SizedBox(width: 48),
                    // Legal links
                    _FooterColumn(title: 'Legal', items: [
                      _FooterItem('Terms of Service', () => context.go('/terms')),
                      _FooterItem('Return Policy', () => context.go('/returns')),
                      _FooterItem('Privacy Policy', () => context.go('/privacy')),
                    ]),
                  ],
                ),
                const SizedBox(height: 40),
                Divider(color: Colors.white.withAlpha(20), height: 1),
                const SizedBox(height: 20),
                _copyright(),
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
      child: Image.asset('assets/images/hotrest_logo.webp', width: 40, height: 40, fit: BoxFit.contain),
    ),
    const SizedBox(width: 10),
    ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [_C.goldLight, _C.gold],
      ).createShader(bounds),
      child: const Text('HotRest',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
    ),
  ]);

  Widget _tagline() => Text(
    'Built for hospitality. Designed for excellence.',
    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13),
  );

  Widget _copyright() => Text(
    '© 2025 HotRest. All rights reserved.',
    style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 12),
  );

  Widget _links(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      _footerLink('Sign In', () => context.go('/login')),
      _footerLink('Get Started', () => context.go('/signup')),
      _footerLink('Terms', () => context.go('/terms')),
      _footerLink('Returns', () => context.go('/returns')),
      _footerLink('Privacy', () => context.go('/privacy')),
    ],
  );

  Widget _footerLink(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
    child: Text(label, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13)),
  );
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<_FooterItem> items;
  const _FooterColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextButton(
            onPressed: item.onTap,
            style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
            child: Text(item.label,
                style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13)),
          ),
        )),
      ],
    );
  }
}

class _FooterItem {
  final String label;
  final VoidCallback? onTap;
  const _FooterItem(this.label, this.onTap);
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _C.gold.withAlpha(15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _C.gold.withAlpha(50)),
      ),
      child: Text(label,
          style: const TextStyle(
            color: _C.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          )),
    );
  }
}

class _GoldButton extends StatefulWidget {
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
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.small ? 8 : 12),
          boxShadow: _hovered
              ? [BoxShadow(color: _C.gold.withAlpha(80), blurRadius: 20, spreadRadius: 2)]
              : [],
        ),
        child: ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hovered ? _C.goldLight : _C.gold,
            foregroundColor: _C.bg,
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 16 : widget.large ? 36 : 24,
              vertical: widget.small ? 10 : widget.large ? 18 : 14,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.small ? 8 : 12)),
            elevation: 0,
          ),
          child: Text(widget.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: widget.small ? 13 : widget.large ? 16 : 14,
              )),
        ),
      ),
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
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    ],
  );

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.gold.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business_rounded, color: _C.gold, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact Sales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.text)),
                    Text('We\'ll get back to you within 24 hours.',
                        style: TextStyle(color: _C.subtext, fontSize: 13)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _field(_name, 'Full Name', required: true),
            _field(_company, 'Company / Hotel Group', required: true),
            _field(_email, 'Work Email', required: true, email: true),
            _field(_phone, 'Phone Number'),
            _field(_propCount, 'Number of Properties', number: true),
            _field(_message, 'Tell us about your needs', maxLines: 3),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.gold,
                  foregroundColor: _C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, bool email = false, bool number = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : email ? TextInputType.emailAddress : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelStyle: const TextStyle(color: _C.gold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.gold)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (email && !v.contains('@')) return 'Enter a valid email';
                return null;
              }
            : null,
      ),
    );
  }
}
