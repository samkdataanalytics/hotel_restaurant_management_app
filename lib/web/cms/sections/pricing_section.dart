import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/plan_service.dart';
import '../../brand_kit.dart';
import '../data/plans_provider.dart';
import '../model/billing_facts.dart';
import '../model/json_reader.dart';
import '../model/link_target.dart';
import '../model/site_document.dart';
import '../model/tokens.dart';
import '../registry/icon_registry.dart';
import '../registry/section_registry.dart';
import '../render/link_action.dart';
import 'section_head_content.dart';

class PricingFlag {
  const PricingFlag({required this.icon, required this.text, required this.tint});

  factory PricingFlag.fromJson(J j) => PricingFlag(
        icon: IconRegistry.resolve(j.strOrNull('icon')),
        text: expandTokens(j.str('text')),
        // Two named tints, not a free colour: an admin cannot pick text the
        // background swallows.
        tint: j.str('tone') == 'amber' ? LK.amber : LK.teal,
      );

  final IconData icon;
  final String text;
  final Color tint;
}

/// Labels around the plan cards. The plans themselves (names, prices, limits)
/// come from the `plans` table, edited under Superadmin → Plans.
class PricingLabels {
  const PricingLabels({
    required this.monthly,
    required this.annual,
    required this.annualBadge,
    required this.monthlyPeriod,
    required this.annualPeriod,
    required this.featuredBadge,
    required this.cta,
    required this.enterpriseCta,
    required this.customPrice,
    required this.freePrice,
    required this.currency,
    required this.emptyMessage,
    required this.extrasAll,
    required this.extrasPaid,
    required this.extrasEnterprise,
  });

  factory PricingLabels.fromJson(J j) {
    final extras = j.obj('extras');
    return PricingLabels(
      monthly: j.str('monthly', 'Monthly'),
      annual: j.str('annual', 'Annual'),
      annualBadge: expandTokens(j.str('annualBadge')),
      monthlyPeriod: j.str('monthlyPeriod', '/month'),
      annualPeriod: j.str('annualPeriod', '/mo, billed annually'),
      featuredBadge: j.str('featuredBadge'),
      cta: j.str('cta', 'Start free trial'),
      enterpriseCta: j.str('enterpriseCta', 'Contact sales'),
      customPrice: j.str('customPrice', 'Custom'),
      freePrice: j.str('freePrice', 'Free'),
      currency: j.str('currency', 'LKR'),
      emptyMessage: j.str('emptyMessage'),
      extrasAll: extras.strings('all'),
      extrasPaid: extras.strings('paid'),
      extrasEnterprise: extras.strings('enterprise'),
    );
  }

  final String monthly;
  final String annual;
  final String annualBadge;
  final String monthlyPeriod;
  final String annualPeriod;
  final String featuredBadge;
  final String cta;
  final String enterpriseCta;
  final String customPrice;
  final String freePrice;
  final String currency;
  final String emptyMessage;

  /// Feature lines added after the plan's own limits: on every plan, on paid
  /// plans only, and on custom-price (enterprise) plans only.
  final List<String> extrasAll;
  final List<String> extrasPaid;
  final List<String> extrasEnterprise;
}

class PricingContent {
  const PricingContent({required this.head, required this.flags, required this.labels});

  factory PricingContent.fromJson(J j) => PricingContent(
        head: HeadContent(
          eyebrow: j.str('eyebrow'),
          title: j.str('title'),
          lead: j.strOrNull('lead') == null ? null : expandTokens(j.str('lead')),
        ),
        flags: j.list('flags', PricingFlag.fromJson).where((f) => f.text.isNotEmpty).toList(),
        labels: PricingLabels.fromJson(j.obj('labels')),
      );

  final HeadContent head;
  final List<PricingFlag> flags;
  final PricingLabels labels;
}

final pricingDefinition = SectionDefinition(
  type: 'pricing',
  label: 'Pricing',
  builder: (context, SectionNode node) =>
      PricingSection(content: PricingContent.fromJson(node.content)),
);

class PricingSection extends ConsumerStatefulWidget {
  const PricingSection({super.key, required this.content});

  final PricingContent content;

  @override
  ConsumerState<PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends ConsumerState<PricingSection> {
  bool _annual = false;

  @override
  Widget build(BuildContext context) {
    final mobile = LK.isMobile(context);
    final content = widget.content;
    final labels = content.labels;
    final plansAsync = ref.watch(activePlansProvider);

    return Shell(
      child: Column(
        children: [
          SectionHead(
            eyebrow: content.head.eyebrow,
            title: content.head.title,
            lead: content.head.lead,
          ),
          if (content.flags.isNotEmpty) ...[
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in content.flags) _Flag(icon: f.icon, text: f.text, tint: f.tint),
              ],
            ),
          ],
          const SizedBox(height: 30),
          _BillingToggle(
            labels: labels,
            annual: _annual,
            onChanged: (v) => setState(() => _annual = v),
          ),
          SizedBox(height: mobile ? 30 : 42),
          plansAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(color: LK.navy)),
            ),
            // A failed fetch reads the same as no plans: the page stays up and
            // says so, rather than showing an error to a prospective customer.
            error: (_, __) => _empty(labels),
            data: (plans) {
              if (plans.isEmpty) return _empty(labels);
              // "Most popular" means one plan. The plans table currently flags
              // more than one as highlighted, so only the first is featured
              // here — two emphasised cards read as a mistake and neither one
              // pulls the eye.
              final featured = plans.indexWhere((p) => p.isHighlighted);

              return LayoutBuilder(builder: (_, c) {
                final cols = c.maxWidth > 980 ? plans.length : (c.maxWidth > 640 ? 2 : 1);
                const gap = 16.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < plans.length; i++)
                      SizedBox(
                        width: w,
                        child: _PlanCard(
                          plan: plans[i],
                          labels: labels,
                          annual: _annual,
                          featured: i == featured,
                        ),
                      ),
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _empty(PricingLabels labels) => Text(
        labels.emptyMessage.isEmpty
            ? 'Pricing is being updated — please check back shortly.'
            : labels.emptyMessage,
        style: LK.small,
      );
}

class _Flag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color tint;
  const _Flag({required this.icon, required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tint.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: LK.micro.copyWith(
                    color: tint, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final PricingLabels labels;
  final bool annual;
  final ValueChanged<bool> onChanged;
  const _BillingToggle({required this.labels, required this.annual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: LK.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: LK.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(labels.monthly, !annual, () => onChanged(false)),
          _seg(labels.annual, annual, () => onChanged(true),
              badge: labels.annualBadge.isEmpty ? null : labels.annualBadge),
        ],
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback onTap, {String? badge}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: on ? LK.white : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            boxShadow: on
                ? [BoxShadow(color: LK.ink.withValues(alpha: 0.07), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: on ? LK.ink : LK.muted,
                  fontSize: 14,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: LK.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(badge,
                      style: LK.micro.copyWith(
                          fontSize: 10, color: LK.teal, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 4999.0 -> "4999". dart2js already prints whole doubles without ".0", the VM
/// does not; spelling it out keeps the page and the tests saying the same thing.
String _money(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final PricingLabels labels;
  final bool annual;

  /// Decided by the section, not by `plan.isHighlighted`, so exactly one card
  /// can ever be featured.
  final bool featured;
  const _PlanCard({
    required this.plan,
    required this.labels,
    required this.annual,
    required this.featured,
  });

  List<String> get _features {
    String limit(int v) => v == -1 ? 'Unlimited' : '$v';
    return [
      '${limit(plan.maxProperties)} ${plan.maxProperties == 1 ? 'property' : 'properties'}',
      '${limit(plan.maxRooms)} rooms',
      '${limit(plan.maxUsers)} staff accounts',
      '${limit(plan.maxTables)} restaurant tables',
      ...labels.extrasAll,
      if (plan.slug != 'free') ...labels.extrasPaid,
      if (plan.isCustomPrice) ...labels.extrasEnterprise,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = plan.isCustomPrice;

    // Annual billing is a discount on the monthly rate; the percentage is a
    // BillingFacts constant because the checkout applies the same one.
    final monthly = annual && !enterprise && plan.priceMonthly > 0
        ? BillingFacts.annualMonthly(plan.priceMonthly)
        : plan.priceMonthly;
    final price = enterprise
        ? labels.customPrice
        : monthly == 0
            ? labels.freePrice
            : '${labels.currency} ${_money(monthly)}';
    final period = annual && !enterprise && monthly > 0
        ? labels.annualPeriod
        : (plan.priceMonthly > 0 ? labels.monthlyPeriod : '');

    final signup = LinkTarget(
      LinkKind.internal,
      monthly > 0 ? '/signup?plan=${plan.slug}' : '/signup',
    );

    return Container(
      padding: EdgeInsets.all(featured ? 28 : 26),
      decoration: BoxDecoration(
        color: featured ? LK.navy : LK.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: featured ? LK.navy : LK.line,
          width: featured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: featured
                ? LK.navy.withValues(alpha: 0.28)
                : LK.ink.withValues(alpha: 0.04),
            blurRadius: featured ? 44 : 16,
            offset: Offset(0, featured ? 18 : 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                plan.name,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: featured ? Colors.white : LK.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (featured && labels.featuredBadge.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: LK.tealLift,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    labels.featuredBadge,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: LK.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          // Wrap, not Row: on the annual toggle the period becomes
          // "/mo, billed annually", which is wider than the space left beside
          // the figure. In a Row the price was the flexible child, so it was
          // the one that shrank — every card rendered "LKR …" with the number
          // ellipsised away. Here each keeps its intrinsic width and the
          // period drops to its own line when it cannot sit alongside.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 7,
            runSpacing: 2,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Text(
                  price,
                  key: ValueKey(price),
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: featured ? Colors.white : LK.ink,
                    fontSize: enterprise ? 28 : 36,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -1.4,
                  ),
                ),
              ),
              if (period.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    period,
                    style: LK.micro.copyWith(
                      fontSize: 11.5,
                      color: featured ? Colors.white.withValues(alpha: 0.6) : LK.muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Divider(
            height: 1,
            color: featured ? Colors.white.withValues(alpha: 0.14) : LK.line,
          ),
          const SizedBox(height: 18),
          for (final f in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: featured ? LK.tealLift : LK.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: LK.small.copyWith(
                        fontSize: 13.5,
                        color: featured ? Colors.white.withValues(alpha: 0.82) : LK.body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          if (enterprise)
            GhostButton(
              label: labels.enterpriseCta,
              expand: true,
              onDark: featured,
              onTap: () => runLink(context, const LinkTarget(LinkKind.action, 'openContactSales')),
            )
          else if (featured)
            CtaButton(
              label: labels.cta,
              expand: true,
              onDark: true,
              onTap: () => runLink(context, signup),
            )
          else
            GhostButton(
              label: labels.cta,
              expand: true,
              onTap: () => runLink(context, signup),
            ),
        ],
      ),
    );
  }
}
