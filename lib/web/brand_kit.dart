import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cms/render/type_scope.dart';

/// Compile-time switch for deterministic output: `--dart-define=FREEZE_MOTION=true`.
///
/// Reveal, CountUp and WordCycler all animate on their own, so two screenshots
/// of the same build differ. That makes a pixel comparison against a baseline
/// meaningless — every diff would be motion noise. With this defined each one
/// renders its end state and starts no timers. Release builds leave it unset,
/// so the live site behaves exactly as before.
const bool kFreezeMotion = bool.fromEnvironment('FREEZE_MOTION');

/// Design tokens and shared atoms for the marketing site.
///
/// Kept out of `app_theme.dart` on purpose: that file is the *product* theme
/// that forty panel screens import, and a marketing page wants a different type
/// scale and rhythm from a dense admin table. The brand colours are the one
/// thing both share, and they are re-stated here from the same source values.
class LK {
  LK._();

  // ─── Brand ────────────────────────────────────────────────────────────────
  /// Logo navy. 13.98:1 on white.
  static const navy = Color(0xFF012C58);

  /// Logo teal as drawn — 3.42:1 on white, so it is for fills and large glyphs,
  /// never body text.
  static const tealPure = Color(0xFF0D9B94);

  /// Teal darkened to 4.98:1 on white. The one that carries text.
  static const teal = Color(0xFF0A7D77);

  /// Teal lifted for dark grounds, 7.8:1 on [ink].
  static const tealLift = Color(0xFF3FBDB4);

  // ─── Neutrals ─────────────────────────────────────────────────────────────
  /// Headings. A hair bluer and darker than the brand navy so headlines read as
  /// type rather than as brand, and the navy stays special.
  static const ink = Color(0xFF0A1424);
  static const body = Color(0xFF4A5A70);
  static const muted = Color(0xFF8A99AD);
  static const line = Color(0xFFE4EAF2);
  static const surface = Color(0xFFF7F9FC);
  static const white = Color(0xFFFFFFFF);

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const danger = Color(0xFFE5484D);
  static const amber = Color(0xFFD9900B);

  // ─── Layout ───────────────────────────────────────────────────────────────
  /// Marketing copy stops being readable much past this, and the hero's two
  /// columns stop balancing.
  static const maxContent = 1180.0;
  static const navHeight = 72.0;

  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < 768;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= 768 && w < 1100;
  }

  static double gutter(BuildContext c) => isMobile(c) ? 22 : (isTablet(c) ? 40 : 64);

  /// Vertical rhythm between sections. One number, so the page has a pulse
  /// instead of each section inventing its own spacing.
  static double sectionGap(BuildContext c) => isMobile(c) ? 72 : 128;

  // ─── Type ─────────────────────────────────────────────────────────────────
  // Negative tracking at display sizes is what separates a set headline from
  // default browser text; it is the single highest-leverage typographic move
  // on a page like this.
  static TextStyle display(BuildContext c) => TypeScope.style(
        c,
        TypeSlot.display,
        TextStyle(
          fontFamily: 'Outfit',
          color: ink,
          fontSize: isMobile(c) ? 36 : 60,
          height: 1.06,
          fontWeight: FontWeight.w800,
          letterSpacing: isMobile(c) ? -1.0 : -2.0,
        ),
      );

  static TextStyle h2(BuildContext c) => TypeScope.style(
        c,
        TypeSlot.heading,
        TextStyle(
          fontFamily: 'Outfit',
          color: ink,
          fontSize: isMobile(c) ? 28 : 42,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: isMobile(c) ? -0.7 : -1.3,
        ),
      );

  static TextStyle h3(BuildContext c) => TypeScope.style(
        c,
        TypeSlot.subheading,
        const TextStyle(
          fontFamily: 'Outfit',
          color: ink,
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      );

  static TextStyle lead(BuildContext c) => TypeScope.style(
        c,
        TypeSlot.lead,
        TextStyle(
          fontFamily: 'Outfit',
          color: body,
          fontSize: isMobile(c) ? 16 : 18,
          height: 1.62,
          fontWeight: FontWeight.w400,
        ),
      );

  static const small = TextStyle(
    fontFamily: 'Outfit',
    color: body,
    fontSize: 14.5,
    height: 1.6,
  );

  static const micro = TextStyle(
    fontFamily: 'Outfit',
    color: muted,
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w500,
  );
}

/// Centres a section's content and applies the page gutter.
class Shell extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const Shell({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: LK.gutter(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? LayoutScope.of(context).maxWidth ?? LK.maxContent,
            ),
            child: child,
          ),
        ),
      );
}

/// Small capsule above a section heading.
class Eyebrow extends StatelessWidget {
  final String text;
  final bool onDark;
  const Eyebrow(this.text, {super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? LK.tealLift : LK.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: onDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Outfit',
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Eyebrow + heading + optional lead, centred. Used by most sections.
class SectionHead extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? lead;
  final bool onDark;
  const SectionHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.lead,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Eyebrow(eyebrow, onDark: onDark),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          // Light grounds use the heading style as it comes, so a heading colour
          // set in the theme applies; dark grounds always read white.
          style: onDark ? LK.h2(context).copyWith(color: Colors.white) : LK.h2(context),
        ),
        if (lead != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              lead!,
              textAlign: TextAlign.center,
              style: LK.lead(context).copyWith(
                color: onDark ? Colors.white.withValues(alpha: 0.66) : LK.body,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Filled call to action.
class CtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool onDark;
  final bool expand;
  const CtaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.onDark = false,
    this.expand = false,
  });

  @override
  State<CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<CtaButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // On light grounds the navy carries white text at 14:1. On dark grounds the
    // navy would vanish, so the lifted teal takes over and the label goes navy —
    // white on that teal is only 2.3:1.
    final bg = widget.onDark ? LK.tealLift : LK.navy;
    final fg = widget.onDark ? LK.navy : Colors.white;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: widget.expand ? double.infinity : null,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: _hover ? 0.38 : 0.22),
                blurRadius: _hover ? 26 : 14,
                offset: Offset(0, _hover ? 10 : 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              if (widget.icon != null) ...[
                const SizedBox(width: 9),
                Icon(widget.icon, size: 17, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action.
class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool onDark;
  final bool expand;
  const GhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.onDark = false,
    this.expand = false,
  });

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.onDark ? Colors.white : LK.ink;
    final border = widget.onDark
        ? Colors.white.withValues(alpha: _hover ? 0.5 : 0.24)
        : (_hover ? LK.navy.withValues(alpha: 0.4) : LK.line);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          decoration: BoxDecoration(
            color: widget.onDark
                ? Colors.white.withValues(alpha: _hover ? 0.08 : 0.0)
                : (_hover ? LK.surface : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 17, color: fg),
                const SizedBox(width: 9),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bordered white card that lifts slightly on hover.
class Panel extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool interactive;
  final Color? background;
  final Color? borderColor;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(26),
    this.interactive = true,
    this.background,
    this.borderColor,
  });

  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lifted = widget.interactive && _hover;
    return MouseRegion(
      onEnter: widget.interactive ? (_) => setState(() => _hover = true) : null,
      onExit: widget.interactive ? (_) => setState(() => _hover = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.background ?? LK.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: lifted
                ? LK.teal.withValues(alpha: 0.32)
                : (widget.borderColor ?? LK.line),
          ),
          boxShadow: [
            BoxShadow(
              color: LK.ink.withValues(alpha: lifted ? 0.09 : 0.035),
              blurRadius: lifted ? 30 : 14,
              offset: Offset(0, lifted ? 12 : 4),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Soft brand-coloured blobs behind the hero and CTA bands.
///
/// Painted rather than imported as an image: a 2000px mesh PNG would be a
/// megabyte for something that is three blurred circles.
class MeshBackdrop extends StatelessWidget {
  final List<({Alignment at, Color color, double size, double opacity})> blobs;
  const MeshBackdrop({super.key, required this.blobs});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final b in blobs)
            Align(
              alignment: b.at,
              child: Container(
                width: b.size,
                height: b.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      b.color.withValues(alpha: b.opacity),
                      b.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Faint grid, for the engineered feel behind the hero.
class GridLines extends StatelessWidget {
  final Color color;
  final double spacing;
  const GridLines({super.key, this.color = LK.line, this.spacing = 56});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _GridPainter(color, spacing), child: const SizedBox.expand()));
}

class _GridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  _GridPainter(this.color, this.spacing);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter o) =>
      o.color != color || o.spacing != spacing;
}

/// Fades and lifts its child the first time it scrolls into view.
///
/// Reads the enclosing [Scrollable] rather than taking a controller, so
/// sections can be composed without threading one through.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  final _key = GlobalKey();
  bool _done = false;
  ScrollPosition? _pos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pos?.removeListener(_check);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_check);
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    if (_done || !mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    // Fire a little before the top edge arrives, so the motion finishes about
    // when the reader's eye does.
    if (top < screen * 0.92) {
      _done = true;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kFreezeMotion) return widget.child;
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    return KeyedSubtree(
      key: _key,
      child: AnimatedBuilder(
        animation: curve,
        builder: (_, child) => Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curve.value) * 26),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Counts up to [value] once revealed. Used by the trust bar.
class CountUp extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle style;
  const CountUp({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
  });

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

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
        final t = kFreezeMotion ? 1.0 : Curves.easeOutExpo.transform(_ctrl.value);
        final v = widget.value * t;
        return Text(
          '${widget.prefix}${v.toStringAsFixed(widget.decimals)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

/// Rotates through [items], one at a time, in place.
///
/// The hero headline names a specific pain; rotating the noun lets it name
/// several without the reader having to scan a list.
class WordCycler extends StatefulWidget {
  final List<String> items;
  final TextStyle style;
  const WordCycler({super.key, required this.items, required this.style});

  @override
  State<WordCycler> createState() => _WordCyclerState();
}

class _WordCyclerState extends State<WordCycler> {
  int _i = 0;
  late final _timer = Stream.periodic(const Duration(milliseconds: 2400));

  @override
  Widget build(BuildContext context) {
    if (kFreezeMotion) {
      return Text(widget.items.first, style: widget.style);
    }
    return StreamBuilder<void>(
      stream: _timer,
      builder: (context, _) {
        return ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 620),
            // Sequential, not crossfaded. AnimatedSwitcher runs the outgoing
            // and incoming children at the same time by default, and two
            // left-aligned display words on top of each other reads as a
            // rendering fault rather than a transition. These intervals send
            // the old word out before the new one starts arriving.
            switchOutCurve: const Interval(0, 0.45, curve: Curves.easeIn),
            switchInCurve: const Interval(0.55, 1, curve: Curves.easeOut),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.28),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              widget.items[_i++ % widget.items.length],
              key: ValueKey(_i),
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

/// Max of a list, guarding the empty case.
double maxOf(Iterable<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => math.max(a, b));
