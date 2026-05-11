import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as webpkg;
import '../services/plan_service.dart';
import '../services/lead_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';

// --- Palette ------------------------------------------------------------------
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

// --- Inherited scroll scope ---------------------------------------------------
class _LandingScrollScope extends InheritedWidget {
  final ScrollController controller;
  const _LandingScrollScope({required this.controller, required super.child});

  static ScrollController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LandingScrollScope>()!.controller;

  @override
  bool updateShouldNotify(_LandingScrollScope old) => controller != old.controller;
}

// --- Landing screen -----------------------------------------------------------
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
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
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
          _LandingScrollScope(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  _HeroSection(isMobile: isMobile),
                  _StatsStrip(isMobile: isMobile),
                  _RevealOnScroll(child: _PainSection(isMobile: isMobile)),
                  _RevealOnScroll(child: _HowItWorksSection(isMobile: isMobile)),
                  _RevealOnScroll(
                    child: SizedBox(
                      key: _featuresKey,
                      child: _FeaturesSection(isMobile: isMobile),
                    ),
                  ),
                  _RevealOnScroll(child: _ComparisonSection(isMobile: isMobile)),
                  _RevealOnScroll(child: _TestimonialsSection(isMobile: isMobile)),
                  _RevealOnScroll(
                    child: SizedBox(
                      key: _pricingKey,
                      child: _PricingSection(isMobile: isMobile),
                    ),
                  ),
                  _RevealOnScroll(child: _FaqSection(isMobile: isMobile)),
                  _RevealOnScroll(child: _CtaSection(isMobile: isMobile)),
                  _Footer(isMobile: isMobile),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: _NavBar(
              solid: _navSolid,
              isMobile: isMobile,
              onFeatures: () => _scrollTo(_featuresKey),
              onPricing:  () => _scrollTo(_pricingKey),
              onDocs:     () => context.go('/help'),
            ),
          ),
          const Positioned(
            bottom: 28, right: 28,
            child: _WhatsAppFab(),
          ),
        ],
      ),
    );
  }
}

// --- Reveal-on-scroll wrapper -------------------------------------------------
class _RevealOnScroll extends StatefulWidget {
  final Widget child;
  const _RevealOnScroll({required this.child});
  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>  _opacity;
  late Animation<Offset>  _slide;
  final _key = GlobalKey();
  bool _revealed = false;
  double _screenH = 0;
  ScrollController? _sc;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sc?.removeListener(_check);
    _sc = _LandingScrollScope.of(context);
    _sc!.addListener(_check);
  }

  @override
  void dispose() {
    _sc?.removeListener(_check);
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (_revealed || !mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    if (_screenH == 0) return;
    if (pos.dy < _screenH * 0.93) {
      _revealed = true;
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenH = MediaQuery.of(context).size.height;
    return FadeTransition(
      key: _key,
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// --- Navigation bar -----------------------------------------------------------
class _NavBar extends StatelessWidget {
  final bool solid;
  final bool isMobile;
  final VoidCallback onFeatures;
  final VoidCallback onPricing;
  final VoidCallback onDocs;
  const _NavBar({required this.solid, required this.isMobile, required this.onFeatures, required this.onPricing, required this.onDocs});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 100,
      decoration: BoxDecoration(
        color: solid ? Colors.white.withAlpha(248) : Colors.transparent,
        border: solid ? const Border(bottom: BorderSide(color: _C.border, width: 1)) : null,
        boxShadow: solid ? [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 20)] : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60),
      child: Row(
        children: [
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
            _NavLink(label: 'Docs',     onTap: onDocs),
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

// --- Animated logo ------------------------------------------------------------
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
        final blurOuter  = 60 + _pulse.value * 60;
        final blurInner  = 20 + _pulse.value * 30;
        final spreadOuter = 8 + _pulse.value * 14;
        final innerAlpha = (60  + _pulse.value * 100).round().clamp(0, 255);
        final outerAlpha = (20  + _pulse.value *  50).round().clamp(0, 255);

        return ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _C.gold.withAlpha(innerAlpha), blurRadius: blurInner, spreadRadius: spreadOuter / 2),
                BoxShadow(color: _C.goldLight.withAlpha(outerAlpha), blurRadius: blurOuter, spreadRadius: spreadOuter),
              ],
            ),
            child: Image.asset('assets/images/hotrest_logo.webp',
                width: widget.size, height: widget.size, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

// --- Hero section -------------------------------------------------------------
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
          colors: [Color(0xFFFFF8E8), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        children: [
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
                Text('Trusted by 500+ Properties Worldwide',
                    style: TextStyle(color: _C.gold, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Stop Running Your Hotel\nWith WhatsApp & Spreadsheets',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 32 : 60,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              'Independent hotels and restaurants waste hours every day '
              'juggling check-ins on WhatsApp, menus on paper, and finances in Excel. '
              'HotRest replaces all of it � one beautiful dashboard for every department.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.subtext, fontSize: isMobile ? 15 : 17, height: 1.65),
            ),
          ),
          const SizedBox(height: 36),
          // CTA buttons
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _GoldButton(label: 'Start Free Trial', onTap: () => context.go('/signup'), large: true),
              OutlinedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const _DemoDialog(),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: _C.gold),
                label: const Text('Watch Demo', style: TextStyle(color: _C.gold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.gold, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: _C.muted),
              SizedBox(width: 5),
              Text('No credit card required � Free forever on Starter plan',
                  style: TextStyle(color: _C.muted, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 64),
          _DashboardMockup(isMobile: isMobile),
        ],
      ),
    );
  }
}

// --- Stats strip (animated count-up) -----------------------------------------
class _StatsStrip extends StatefulWidget {
  final bool isMobile;
  const _StatsStrip({required this.isMobile});
  @override
  State<_StatsStrip> createState() => _StatsStripState();
}

class _StatsStripState extends State<_StatsStrip> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  final _key = GlobalKey();
  bool _triggered = false;
  double _screenH = 0;
  ScrollController? _sc;

  static const _stats = [
    (target: 500.0, decimals: 0, suffix: '+',  label: 'Properties'),
    (target: 50.0,  decimals: 0, suffix: 'K+', label: 'Bookings Managed'),
    (target: 99.9,  decimals: 1, suffix: '%',  label: 'Uptime SLA'),
    (target: 4.9,   decimals: 1, suffix: '?', label: 'Average Rating'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sc?.removeListener(_check);
    _sc = _LandingScrollScope.of(context);
    _sc!.addListener(_check);
  }

  @override
  void dispose() {
    _sc?.removeListener(_check);
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (_triggered || !mounted || _screenH == 0) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    if (pos.dy < _screenH * 0.98) {
      _triggered = true;
      _ctrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenH = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        key: _key,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 24 : 80, vertical: 40),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
        ),
        child: widget.isMobile
            ? Wrap(
                spacing: 32,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: _stats.map((s) => _AnimatedStatItem(
                  value: s.target * _anim.value,
                  decimals: s.decimals,
                  suffix: s.suffix,
                  label: s.label,
                )).toList(),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _stats.map((s) => _AnimatedStatItem(
                  value: s.target * _anim.value,
                  decimals: s.decimals,
                  suffix: s.suffix,
                  label: s.label,
                )).toList(),
              ),
      ),
    );
  }
}

class _AnimatedStatItem extends StatelessWidget {
  final double value;
  final int    decimals;
  final String suffix, label;
  const _AnimatedStatItem({required this.value, required this.decimals, required this.suffix, required this.label});

  @override
  Widget build(BuildContext context) {
    final display = decimals == 0 ? value.toInt().toString() : value.toStringAsFixed(decimals);
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              const LinearGradient(colors: [_C.goldLight, _C.gold]).createShader(bounds),
          child: Text('$display$suffix',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13,
                fontWeight: FontWeight.w500, letterSpacing: 0.3)),
      ],
    );
  }
}

// --- How It Works -------------------------------------------------------------
class _HowItWorksSection extends StatelessWidget {
  final bool isMobile;
  const _HowItWorksSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
      child: Column(
        children: [
          const _SectionLabel(label: 'HOW IT WORKS'),
          const SizedBox(height: 16),
          Text(
            'Up and Running\nin Under 20 Minutes',
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
            constraints: const BoxConstraints(maxWidth: 500),
            child: const Text(
              'No consultants. No training sessions. Just sign up and go.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.subtext, fontSize: 15.5, height: 1.55),
            ),
          ),
          const SizedBox(height: 56),
          isMobile
              ? Column(children: [
                  _StepCard(number: '01', icon: Icons.business_rounded,    color: Color(0xFF3B82F6), title: 'Set Up Your Property',    desc: 'Add your hotel details, configure room types, build your restaurant menu, and invite staff � all in one onboarding flow.'),
                  const SizedBox(height: 32),
                  _StepCard(number: '02', icon: Icons.dashboard_rounded,   color: _C.gold,           title: 'Manage Everything',       desc: 'Check guests in, process restaurant orders, track staff shifts, and monitor occupancy from one unified dashboard.'),
                  const SizedBox(height: 32),
                  _StepCard(number: '03', icon: Icons.trending_up_rounded, color: Color(0xFF22C55E), title: 'Grow Your Business',       desc: 'Use built-in analytics to optimise pricing, spot peak periods, and make data-driven decisions that increase revenue.'),
                ])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StepCard(number: '01', icon: Icons.business_rounded,    color: Color(0xFF3B82F6), title: 'Set Up Your Property',    desc: 'Add your hotel details, configure room types, build your restaurant menu, and invite staff � all in one onboarding flow.')),
                    Padding(
                      padding: const EdgeInsets.only(top: 52),
                      child: Icon(Icons.arrow_forward_rounded, color: _C.border, size: 28),
                    ),
                    Expanded(child: _StepCard(number: '02', icon: Icons.dashboard_rounded,   color: _C.gold,           title: 'Manage Everything',       desc: 'Check guests in, process restaurant orders, track staff shifts, and monitor occupancy from one unified dashboard.')),
                    Padding(
                      padding: const EdgeInsets.only(top: 52),
                      child: Icon(Icons.arrow_forward_rounded, color: _C.border, size: 28),
                    ),
                    Expanded(child: _StepCard(number: '03', icon: Icons.trending_up_rounded, color: Color(0xFF22C55E), title: 'Grow Your Business',       desc: 'Use built-in analytics to optimise pricing, spot peak periods, and make data-driven decisions that increase revenue.')),
                  ],
                ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number, title, desc;
  final IconData icon;
  final Color    color;
  const _StepCard({required this.number, required this.icon, required this.color,
      required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: color.withAlpha(22), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            Positioned(
              top: -6, right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(number,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.subtext, fontSize: 14, height: 1.6)),
      ],
    );
  }
}

// --- Animated dashboard mockup ------------------------------------------------
class _DashboardMockup extends StatefulWidget {
  final bool isMobile;
  const _DashboardMockup({required this.isMobile});
  @override
  State<_DashboardMockup> createState() => _DashboardMockupState();
}

class _DashboardMockupState extends State<_DashboardMockup> {
  int    _idx   = 0;
  Timer? _timer;

  static const _datasets = [
    (occ: '87%', occTrend: '+4%',  rev: '\$4,280', revTrend: '+12%', orders: '12', ordersTrend: '? Busy',   checkins: '8',  checkinsTrend: '3 pending'),
    (occ: '91%', occTrend: '+7%',  rev: '\$5,140', revTrend: '+20%', orders: '17', ordersTrend: '? Peak',   checkins: '11', checkinsTrend: '5 pending'),
    (occ: '79%', occTrend: '-2%',  rev: '\$3,960', revTrend: '+3%',  orders: '9',  ordersTrend: '? Steady', checkins: '6',  checkinsTrend: '2 pending'),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _idx = (_idx + 1) % _datasets.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _datasets[_idx];
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
                  decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(4)),
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
                child: const Text('? Live',
                    style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          // Dashboard content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Good morning, Alex ??',
                        style: TextStyle(color: _C.text, fontSize: 13, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.gold.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.gold.withAlpha(60)),
                      ),
                      child: const Text('Grand Ocean Hotel',
                          style: TextStyle(color: _C.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _StatCard(label: 'Occupancy',       value: d.occ,    icon: Icons.king_bed_rounded,    color: const Color(0xFF22C55E), trend: d.occTrend),
                    const SizedBox(width: 10),
                    _StatCard(label: "Today's Revenue", value: d.rev,    icon: Icons.attach_money_rounded, color: _C.gold,                trend: d.revTrend),
                    const SizedBox(width: 10),
                    if (!widget.isMobile) _StatCard(label: 'Active Orders',   value: d.orders, icon: Icons.restaurant_rounded,   color: const Color(0xFFF97316), trend: d.ordersTrend),
                    if (!widget.isMobile) const SizedBox(width: 10),
                    if (!widget.isMobile) _StatCard(label: 'Check-Ins Today', value: d.checkins, icon: Icons.how_to_reg_rounded,  color: const Color(0xFF3B82F6), trend: d.checkinsTrend),
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

  Widget _dot(Color c) =>
      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final String? trend;
  final IconData icon;
  final Color    color;
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(trend!, key: ValueKey(trend),
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(value, key: ValueKey(value),
                style: const TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          Text(label, style: const TextStyle(color: _C.subtext, fontSize: 9.5)),
        ]),
      ),
    );
  }
}

class _MockChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bars   = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.75];
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      height: 90,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (i) => Expanded(
                child: Padding(
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
                ),
              )),
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
      decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Room Status', style: TextStyle(color: _C.subtext, fontSize: 8.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Expanded(
            child: Wrap(
              spacing: 4, runSpacing: 4,
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
                  child: Text(r.$1,
                      style: const TextStyle(color: Colors.white, fontSize: 6.5, fontWeight: FontWeight.w700)),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Features section ---------------------------------------------------------
class _FeaturesSection extends StatelessWidget {
  final bool isMobile;
  const _FeaturesSection({required this.isMobile});

  static const _features = [
    (icon: Icons.king_bed_rounded,    color: Color(0xFF3B82F6), title: 'Hotel Management',
      bullets: ['Room setup, types & availability', 'Reservations & walk-in check-in/out', 'Folio billing & payment tracking', 'Housekeeping task management', 'Occupancy & room status overview']),
    (icon: Icons.point_of_sale_rounded, color: Color(0xFFF97316), title: 'Restaurant POS',
      bullets: ['Table-side & counter ordering', 'Live kitchen display system (KDS)', 'Menu & category management', 'Split bills & multiple payment modes', 'Real-time sales analytics']),
    (icon: Icons.qr_code_2_rounded,   color: Color(0xFF22C55E), title: 'Guest Portal',
      bullets: ['QR-based self check-in & check-out', 'Room service ordering via phone', 'Digital menus � no app download', 'Booking lookup & stay details', 'Direct messaging with front desk']),
    (icon: Icons.palette_rounded,     color: Color(0xFFD4A853), title: 'White-Label Ready',
      bullets: ['Custom brand colors & logo', 'Property name on all guest screens', 'Branded QR codes & menus', 'No HotRest branding visible to guests', 'Multi-property brand profiles']),
    (icon: Icons.people_alt_rounded,  color: Color(0xFF8B5CF6), title: 'Staff & Shifts',
      bullets: ['Role-based access control', 'Shift scheduling & clock-in/out', 'Time tracking & attendance logs', 'Staff invite via unique code', 'Per-property permission management']),
    (icon: Icons.analytics_rounded,   color: Color(0xFF06B6D4), title: 'Financial Reports',
      bullets: ['Daily revenue & expense summaries', 'Invoice & folio export to PDF', 'Occupancy rate tracking', 'Restaurant sales breakdown', 'Date-range custom reporting']),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
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
              'Purpose-built for hotels and restaurants � not a bloated ERP. '
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
                  _FeatureCard(icon: f.icon, color: f.color, title: f.title, bullets: f.bullets)).toList(),
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
            Text(widget.title,
                style: const TextStyle(color: _C.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
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
                    child: Text(b,
                        style: const TextStyle(color: _C.subtext, fontSize: 12.5, height: 1.45)),
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

// --- Testimonials section -----------------------------------------------------
class _TestimonialsSection extends StatelessWidget {
  final bool isMobile;
  const _TestimonialsSection({required this.isMobile});

  static const _testimonials = [
    (
      quote: 'HotRest cut our front-desk workload in half. Check-in used to take 5 minutes per guest � now guests self-check in via QR. The staff scheduling alone is worth every cent.',
      name: 'Sarah Mitchell', role: 'General Manager', hotel: 'The Riverview Boutique Hotel',
      initials: 'SM', color: Color(0xFF3B82F6),
    ),
    (
      quote: 'We run 3 properties and the multi-property dashboard is a game-changer. I can see revenue, occupancy and active restaurant orders for all locations in one screen. Incredible.',
      name: 'James Okonkwo', role: 'Director of Operations', hotel: 'Okonkwo Hospitality Group',
      initials: 'JO', color: Color(0xFFD4A853),
    ),
    (
      quote: 'Switching from our old PMS was painless. The onboarding took less than 20 minutes, and the white-label guest portal means our branding is front and center � not some software company\'s logo.',
      name: 'Priya Ramaswamy', role: 'Owner', hotel: 'Serenity Suites & Restaurant',
      initials: 'PR', color: Color(0xFF22C55E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
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
          Row(children: List.generate(5, (_) => const Icon(Icons.star_rounded, color: _C.gold, size: 16))),
          const SizedBox(height: 16),
          Text('"$quote"',
              style: const TextStyle(color: _C.text, fontSize: 13.5, height: 1.65, fontStyle: FontStyle.italic)),
          const Spacer(),
          const SizedBox(height: 20),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 16),
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
                    Text(name,
                        style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('$role � $hotel',
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

// --- Pricing section (dynamic from DB + billing toggle) -----------------------
class _PricingSection extends ConsumerStatefulWidget {
  final bool isMobile;
  const _PricingSection({required this.isMobile});
  @override
  ConsumerState<_PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends ConsumerState<_PricingSection> {
  late Future<List<PlanModel>> _future;
  bool _isAnnual = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(planServiceProvider).getActivePlans();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 24 : 80, vertical: widget.isMobile ? 60 : 100),
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
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withAlpha(12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department_rounded, color: Color(0xFFEF4444), size: 14),
                SizedBox(width: 7),
                Text('Early-Access Pricing � Rates locked in for life when you sign up now',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Billing toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: !_isAnnual ? _C.text : _C.muted,
                  fontWeight: !_isAnnual ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
                child: const Text('Monthly'),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => setState(() => _isAnnual = !_isAnnual),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 48, height: 26,
                  decoration: BoxDecoration(
                    color: _isAnnual ? _C.gold : _C.border,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    alignment: _isAnnual ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: _isAnnual ? _C.text : _C.muted,
                  fontWeight: _isAnnual ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
                child: const Text('Annual'),
              ),
              if (_isAnnual) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF22C55E).withAlpha(60)),
                  ),
                  child: const Text('Save 20%',
                      style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 40),
          FutureBuilder<List<PlanModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
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
                          Expanded(child: _PricingCard(plan: plans[i], isAnnual: _isAnnual)),
                        ],
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < plans.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _PricingCard(plan: plans[i], isAnnual: _isAnnual),
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
  final bool isAnnual;
  const _PricingCard({required this.plan, required this.isAnnual});

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
    final isEnterprise = plan.isCustomPrice;
    final effectiveMonthly = isAnnual && !isEnterprise && plan.priceMonthly > 0
        ? (plan.priceMonthly * 0.8).round()
        : plan.priceMonthly;
    final priceStr = isEnterprise
        ? 'Custom'
        : effectiveMonthly == 0
            ? 'Free'
            : 'LKR $effectiveMonthly';
    final periodStr = isAnnual && !isEnterprise && effectiveMonthly > 0
        ? '/ mo, billed annually'
        : plan.priceMonthly > 0 ? '/ month' : '';

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
                decoration: BoxDecoration(color: _C.gold, borderRadius: BorderRadius.circular(20)),
                child: const Text('Most Popular',
                    style: TextStyle(color: _C.bg, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(priceStr, key: ValueKey(priceStr),
                  style: TextStyle(
                    color: highlighted ? _C.goldLight : _C.text,
                    fontSize: isEnterprise ? 28 : 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  )),
            ),
            if (!isEnterprise && plan.priceMonthly > 0) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(periodStr, key: ValueKey(periodStr),
                      style: const TextStyle(color: _C.subtext, fontSize: 13)),
                ),
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
                  size: 16, color: highlighted ? _C.gold : const Color(0xFF22C55E)),
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
                    onPressed: () => context.go(
                      effectiveMonthly > 0
                          ? '/signup?plan=${plan.slug}'
                          : '/signup',
                    ),
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
                        showDialog(context: context, builder: (_) => const _EnterpriseContactDialog());
                      } else {
                        context.go(
                          effectiveMonthly > 0
                              ? '/signup?plan=${plan.slug}'
                              : '/signup',
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.text,
                      side: const BorderSide(color: _C.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEnterprise ? 'Contact Sales' : 'Get Started',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
          ),
        ],
      ),
    );
  }
}

// --- FAQ section --------------------------------------------------------------
class _FaqSection extends StatelessWidget {
  final bool isMobile;
  const _FaqSection({required this.isMobile});

  static const _faqs = [
    (
      q: 'Is there a free plan?',
      a: 'Yes! Our Starter plan is free forever with up to 1 property, 10 rooms, 5 staff accounts, and 5 restaurant tables. No credit card required � just sign up and start managing.',
    ),
    (
      q: 'Can I manage multiple properties?',
      a: 'Absolutely. Our Pro plan supports up to 3 properties, and the Enterprise plan offers unlimited properties with a dedicated account manager and SLA guarantees.',
    ),
    (
      q: 'Do guests need to download an app?',
      a: 'No. The guest portal works entirely via QR code in any mobile browser. Guests can check in, browse the restaurant menu, order room service, and check out � no download required.',
    ),
    (
      q: 'How secure is guest and payment data?',
      a: 'Very. HotRest is built on enterprise-grade infrastructure with row-level security, encrypted data at rest and in transit, GDPR-ready data handling, and SOC 2 aligned practices.',
    ),
    (
      q: 'Can I white-label the guest portal?',
      a: 'Yes, on Pro and Enterprise plans. You can set your own logo, brand colours, and property name. Guests see your brand � not ours.',
    ),
    (
      q: 'Can I cancel or downgrade anytime?',
      a: 'Of course. There are no long-term contracts. You can upgrade, downgrade, or cancel your plan at any time from account settings. Monthly billing, no lock-in.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
      child: Column(
        children: [
          const _SectionLabel(label: 'FAQ'),
          const SizedBox(height: 16),
          Text(
            'Frequently Asked Questions',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text,
              fontSize: isMobile ? 28 : 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: _faqs.map((faq) => _FaqTile(q: faq.q, a: faq.a)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _open ? _C.gold.withAlpha(8) : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _open ? _C.gold.withAlpha(80) : _C.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.q,
                          style: TextStyle(
                            color: _open ? _C.gold : _C.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.add_rounded, color: _open ? _C.gold : _C.subtext, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(widget.a,
                    style: const TextStyle(color: _C.subtext, fontSize: 14, height: 1.65)),
              ),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CTA section --------------------------------------------------------------
class _CtaSection extends StatelessWidget {
  final bool isMobile;
  const _CtaSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 80),
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
                    Text('Get started in under 5 minutes',
                        style: TextStyle(color: _C.gold, fontSize: 12, fontWeight: FontWeight.w700)),
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
                'Join hundreds of hospitality teams already running smarter with HotRest.\nNo credit card required � start in minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 36),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _GoldButton(label: 'Create Free Account', large: true, onTap: () => context.go('/signup')),
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
              const Wrap(
                spacing: 24,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _TrustChip(icon: Icons.lock_outline_rounded,  label: 'SOC 2 Compliant'),
                  _TrustChip(icon: Icons.shield_outlined,       label: 'GDPR Ready'),
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

// --- Footer -------------------------------------------------------------------
class _Footer extends StatelessWidget {
  final bool isMobile;
  const _Footer({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 48),
      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
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
                    _FooterColumn(title: 'Product', items: [
                      const _FooterItem('Features', null),
                      const _FooterItem('Pricing', null),
                      _FooterItem('Docs', () => context.go('/help')),
                      _FooterItem('Sign In', () => context.go('/login')),
                      _FooterItem('Get Started', () => context.go('/signup')),
                    ]),
                    const SizedBox(width: 48),
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
      shaderCallback: (bounds) =>
          const LinearGradient(colors: [_C.goldLight, _C.gold]).createShader(bounds),
      child: const Text('HotRest', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
    ),
  ]);

  Widget _tagline() => Text(
    'Built for hospitality. Designed for excellence.',
    style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13),
  );

  Widget _copyright() => Text(
    '� 2025 HotRest. All rights reserved.',
    style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 12),
  );

  Widget _links(BuildContext context) => Wrap(
    spacing: 20, runSpacing: 8,
    alignment: WrapAlignment.center,
    children: [
      _footerLink('Sign In',     () => context.go('/login')),
      _footerLink('Get Started', () => context.go('/signup')),
      _footerLink('Terms',       () => context.go('/terms')),
      _footerLink('Returns',     () => context.go('/returns')),
      _footerLink('Privacy',     () => context.go('/privacy')),
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
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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

// --- Shared helpers -----------------------------------------------------------
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
  const _GoldButton({required this.label, required this.onTap, this.large = false, this.small = false});
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
              vertical:   widget.small ? 10 : widget.large ? 18 : 14,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.small ? 8 : 12)),
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

// --- Demo Dialog --------------------------------------------------------------
class _DemoDialog extends StatefulWidget {
  const _DemoDialog();
  @override
  State<_DemoDialog> createState() => _DemoDialogState();
}

class _DemoDialogState extends State<_DemoDialog> {
  int _activeTab = 0;

  static const _tabs = ['Hotel', 'Restaurant', 'Guest Portal'];

  static const _highlights = [
    [
      (icon: Icons.how_to_reg_rounded,   color: Color(0xFF3B82F6), title: 'One-click check-in',        desc: 'Front desk checks in a guest in under 10 seconds � folio auto-generated, room assigned, key ready.'),
      (icon: Icons.king_bed_rounded,      color: Color(0xFF22C55E), title: 'Live room availability',    desc: 'Color-coded room grid shows occupied, available, and maintenance rooms in real time.'),
      (icon: Icons.receipt_long_rounded,  color: Color(0xFFD4A853), title: 'Instant folio billing',     desc: 'Auto-calculates room charges, extras and taxes � export to PDF with one click.'),
      (icon: Icons.people_alt_rounded,    color: Color(0xFF8B5CF6), title: 'Staff shift management',    desc: 'Assign and track shifts, clock-ins and attendance � no third-party HR tool needed.'),
    ],
    [
      (icon: Icons.point_of_sale_rounded, color: Color(0xFFF97316), title: 'Table-side ordering',       desc: 'Waiters take orders on any device � sent instantly to the kitchen display, no paper tickets.'),
      (icon: Icons.kitchen_rounded,       color: Color(0xFFEF4444), title: 'Kitchen display system',    desc: 'KDS shows orders in real time, with timers and priority flags so chefs never miss a ticket.'),
      (icon: Icons.splitscreen_rounded,   color: Color(0xFF22C55E), title: 'Split bills & payments',    desc: 'Split any bill by item or equally across guests � supports cash, card and mixed payments.'),
      (icon: Icons.analytics_rounded,     color: Color(0xFF06B6D4), title: 'Sales analytics',           desc: 'See your top-selling dishes, peak hours, and daily revenue at a glance.'),
    ],
    [
      (icon: Icons.qr_code_2_rounded,    color: Color(0xFF22C55E), title: 'QR self check-in',          desc: 'Guests scan a QR at reception, fill in details on their phone and check in � no queue, no paperwork.'),
      (icon: Icons.room_service_rounded,  color: Color(0xFFD4A853), title: 'Room service on phone',     desc: 'Guests order food from their room by scanning a QR � order goes straight to the kitchen.'),
      (icon: Icons.restaurant_menu_rounded, color: Color(0xFF3B82F6), title: 'Digital table menu',      desc: 'Diners scan a table QR, browse the menu and order � no app download required.'),
      (icon: Icons.no_accounts_rounded,   color: Color(0xFF8B5CF6), title: 'No app needed',             desc: 'Everything runs in the mobile browser. Guests do not install anything.'),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final items = _highlights[_activeTab];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('See HotRest in Action',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.text)),
                        SizedBox(height: 4),
                        Text('What you get � out of the box, day one.',
                            style: TextStyle(color: _C.subtext, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _C.muted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == i ? _C.gold : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(_tabs[i],
                          style: TextStyle(
                            color: _activeTab == i ? Colors.white : _C.subtext,
                            fontSize: 13,
                            fontWeight: _activeTab == i ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )),
                ),
              ),
              const SizedBox(height: 20),
              // Feature highlights grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: items.map((item) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.color.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(item.icon, color: item.color, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item.title,
                            style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(item.desc,
                          style: const TextStyle(color: _C.subtext, fontSize: 10.5, height: 1.45),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/signup');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                  label: const Text('Try It Free � No Credit Card',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Enterprise Contact Dialog ------------------------------------------------
class _EnterpriseContactDialog extends ConsumerStatefulWidget {
  const _EnterpriseContactDialog();
  @override
  ConsumerState<_EnterpriseContactDialog> createState() => _EnterpriseContactDialogState();
}

class _EnterpriseContactDialogState extends ConsumerState<_EnterpriseContactDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _name      = TextEditingController();
  final _company   = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();
  final _message   = TextEditingController();
  final _propCount = TextEditingController();
  LeadService get _service => ref.read(leadServiceProvider);
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
        decoration: BoxDecoration(color: const Color(0xFF22C55E).withAlpha(20), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 36),
      ),
      const SizedBox(height: 20),
      const Text('Request Received!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _C.text)),
      const SizedBox(height: 10),
      const Text(
        'Thank you for reaching out. Our team will contact you within 1�2 business days to discuss your requirements.',
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
                decoration: BoxDecoration(color: _C.gold.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.business_rounded, color: _C.gold, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact Sales',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.text)),
                    Text('We\'ll get back to you within 24 hours.',
                        style: TextStyle(color: _C.subtext, fontSize: 13)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _field(_name,     'Full Name',                required: true),
            _field(_company,  'Company / Hotel Group',    required: true),
            _field(_email,    'Work Email',               required: true, email: true),
            _field(_phone,    'Phone Number'),
            _field(_propCount,'Number of Properties',     number: true),
            _field(_message,  'Tell us about your needs', maxLines: 3),
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
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send Request',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
        keyboardType: number
            ? TextInputType.number
            : email
                ? TextInputType.emailAddress
                : TextInputType.text,
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

// --- Pain section (Before / After) -------------------------------------------
class _PainSection extends StatelessWidget {
  final bool isMobile;
  const _PainSection({required this.isMobile});

  static const _before = [
    (icon: Icons.chat_bubble_rounded,        text: 'WhatsApp & phone calls for every booking'),
    (icon: Icons.table_chart_rounded,        text: 'Spreadsheets that break during peak hours'),
    (icon: Icons.receipt_rounded,            text: 'Paper order tickets lost in the kitchen'),
    (icon: Icons.supervised_user_circle_rounded, text: 'Staff asking each other what to do next'),
    (icon: Icons.alarm_off_rounded,          text: 'Hours wasted on manual data entry daily'),
    (icon: Icons.sentiment_dissatisfied_rounded, text: 'Guests waiting 10 minutes to check in'),
  ];

  static const _after = [
    (icon: Icons.dashboard_rounded,          text: 'One dashboard for front desk, kitchen & finance'),
    (icon: Icons.cloud_sync_rounded,         text: 'Real-time sync across all departments'),
    (icon: Icons.kitchen_rounded,            text: 'Digital kitchen display � zero lost tickets'),
    (icon: Icons.task_alt_rounded,           text: 'Every staff member knows their tasks instantly'),
    (icon: Icons.flash_on_rounded,           text: 'Save 4+ hours of admin work every single day'),
    (icon: Icons.qr_code_2_rounded,          text: 'Guests self-check-in in under 30 seconds'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
        ),
      ),
      child: Column(
        children: [
          const _SectionLabel(label: 'THE DIFFERENCE'),
          const SizedBox(height: 16),
          Text(
            'Life Before & After HotRest',
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
              "Sound familiar? You're not alone. Most independent hotels and "
              'restaurants operate the same way � until they find HotRest.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.subtext, fontSize: 15.5, height: 1.55),
            ),
          ),
          const SizedBox(height: 56),
          isMobile
              ? Column(children: [
                  _PainPanel(title: 'Before HotRest', isAfter: false, items: _before),
                  const SizedBox(height: 20),
                  _PainPanel(title: 'With HotRest', isAfter: true, items: _after),
                ])
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PainPanel(title: 'Before HotRest', isAfter: false, items: _before)),
                      Container(
                        width: 2, margin: const EdgeInsets.symmetric(horizontal: 20),
                        color: _C.border,
                      ),
                      Expanded(child: _PainPanel(title: 'With HotRest', isAfter: true, items: _after)),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class _PainPanel extends StatelessWidget {
  final String title;
  final bool isAfter;
  final List<({IconData icon, String text})> items;
  const _PainPanel({required this.title, required this.isAfter, required this.items});

  @override
  Widget build(BuildContext context) {
    final accent = isAfter ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accent.withAlpha(8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accent.withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Icon(
                isAfter ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: accent, size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: accent, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(item.text,
                        style: TextStyle(
                          color: isAfter ? _C.text : _C.subtext,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: isAfter ? FontWeight.w600 : FontWeight.w400,
                          decoration: isAfter ? null : TextDecoration.none,
                        )),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// --- Comparison section -------------------------------------------------------
class _ComparisonSection extends ConsumerStatefulWidget {
  final bool isMobile;
  const _ComparisonSection({required this.isMobile});

  @override
  ConsumerState<_ComparisonSection> createState() => _ComparisonSectionState();
}

class _ComparisonSectionState extends ConsumerState<_ComparisonSection> {
  bool get isMobile => widget.isMobile;

  String _startingPrice = 'Free / from LKR 3,450';

  static const _features = [
    'Starting price',
    'Setup time',
    'Hotel + Restaurant in one',
    'QR guest self-check-in',
    'Built-in kitchen display',
    'Digital guest menu',
    'Multi-property support',
    'White-label branding',
    'Free plan available',
  ];

  List<dynamic> get _hotrest => [_startingPrice, '< 20 min', true, true, true, true, true, true, true];
  static const _trad   = ['LKR 20,000+/mo',        'Days–Weeks', false, false, false, false, true, false, false];
  static const _manual = ['Ongoing hidden costs', 'Never done',   false, false, false, false, false, false, true];

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    try {
      final plans = await ref.read(planServiceProvider).getActivePlans();
      final starter = plans.where((p) => p.slug == 'starter').firstOrNull;
      if (starter != null && mounted) {
        final price = starter.priceMonthly.toInt();
        final formatted = price.toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
        setState(() => _startingPrice = 'Free / LKR $formatted');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 80, vertical: isMobile ? 60 : 100),
      decoration: const BoxDecoration(color: Color(0xFF0F172A)),
      child: Column(
        children: [
          const _SectionLabel(label: 'WHY HOTREST'),
          const SizedBox(height: 16),
          Text(
            'How We Compare',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 28 : 44,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Traditional hotel software is expensive, slow to set up, and missing key features. '
            'HotRest was built from the ground up for independent properties.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 15.5, height: 1.55),
          ),
          const SizedBox(height: 48),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: isMobile ? _buildMobile() : _buildDesktop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Column(
      children: [
        // Header row
        Row(children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _C.gold,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: const Text('HotRest', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: Text('Traditional PMS', style: TextStyle(color: Colors.white.withAlpha(180), fontWeight: FontWeight.w600, fontSize: 13)),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: Text('Manual / Spreadsheet', style: TextStyle(color: Colors.white.withAlpha(180), fontWeight: FontWeight.w600, fontSize: 12)),
          )),
        ]),
        // Data rows
        ...List.generate(_features.length, (i) => Container(
          decoration: BoxDecoration(
            color: i.isEven ? Colors.white.withAlpha(5) : Colors.transparent,
          ),
          child: Row(children: [
            Expanded(flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Text(_features[i], style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
              ),
            ),
            Expanded(flex: 2, child: _cell(_hotrest[i],  _C.gold,                    isHighlighted: true)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _cell(_trad[i],     Colors.white.withAlpha(130))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _cell(_manual[i],   Colors.white.withAlpha(130))),
          ]),
        )),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildMobile() {
    return Column(
      children: List.generate(_features.length, (i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_features[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _mobileCell('HotRest', _hotrest[i], _C.gold)),
              const SizedBox(width: 6),
              Expanded(child: _mobileCell('Trad. PMS', _trad[i], Colors.white.withAlpha(100))),
              const SizedBox(width: 6),
              Expanded(child: _mobileCell('Manual', _manual[i], Colors.white.withAlpha(100))),
            ]),
          ],
        ),
      )),
    );
  }

  Widget _cell(dynamic value, Color color, {bool isHighlighted = false}) {
    if (value is bool) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          value ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: value ? color : Colors.white.withAlpha(40),
          size: 20,
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Text(value.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w400)),
    );
  }

  Widget _mobileCell(String colLabel, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        children: [
          Text(colLabel, style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 10)),
          const SizedBox(height: 4),
          value is bool
              ? Icon(value ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: value ? color : Colors.white.withAlpha(40), size: 18)
              : Text(value.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// --- Floating WhatsApp button -------------------------------------------------
class _WhatsAppFab extends StatefulWidget {
  const _WhatsAppFab();
  @override
  State<_WhatsAppFab> createState() => _WhatsAppFabState();
}

class _WhatsAppFabState extends State<_WhatsAppFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _hovered = false;

  // Replace with your actual WhatsApp number (international format, no '+' or spaces)
  static const _waNumber  = '94XXXXXXXXX';
  static const _waMessage = 'Hi! I\'m interested in HotRest for my property.';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    final uri = Uri.encodeFull('https://wa.me/$_waNumber?text=$_waMessage');
    webpkg.window.open(uri, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) { setState(() => _hovered = true);  _ctrl.forward(); },
      onExit:  (_) { setState(() => _hovered = false); _ctrl.reverse(); },
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: _open,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withAlpha(_hovered ? 100 : 60),
                  blurRadius: _hovered ? 24 : 14,
                  spreadRadius: _hovered ? 4 : 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _hovered
                      ? const Row(children: [
                          SizedBox(width: 8),
                          Text('Chat with us',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
