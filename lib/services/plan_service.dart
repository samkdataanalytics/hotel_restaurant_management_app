import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class PlanModel {
  final String id;
  final String name;
  final String slug;
  final double priceMonthly;
  final bool isCustomPrice; // true → show "Custom" on landing page
  final int maxProperties;  // -1 = unlimited
  final int maxUsers;
  final int maxRooms;
  final int maxTables;
  final bool isHighlighted;
  final bool isActive;
  final int sortOrder;

  const PlanModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceMonthly,
    required this.isCustomPrice,
    required this.maxProperties,
    required this.maxUsers,
    required this.maxRooms,
    required this.maxTables,
    required this.isHighlighted,
    required this.isActive,
    required this.sortOrder,
  });

  factory PlanModel.fromRow(Map<String, dynamic> r) => PlanModel(
        id:             r['id']              as String,
        name:           r['name']            as String,
        slug:           r['slug']            as String,
        priceMonthly:   (r['price_monthly'] as num).toDouble(),
        isCustomPrice:  r['is_custom_price'] as bool? ?? false,
        maxProperties:  r['max_properties']  as int,
        maxUsers:       r['max_users']       as int,
        maxRooms:       r['max_rooms']       as int,
        maxTables:      r['max_tables']      as int,
        isHighlighted:  r['is_highlighted']  as bool? ?? false,
        isActive:       r['is_active']       as bool? ?? true,
        sortOrder:      r['sort_order']      as int? ?? 0,
      );

  PlanModel copyWith({
    String? name,
    double? priceMonthly,
    bool? isCustomPrice,
    int? maxProperties,
    int? maxUsers,
    int? maxRooms,
    int? maxTables,
    bool? isHighlighted,
    bool? isActive,
  }) => PlanModel(
    id:             id,
    name:           name           ?? this.name,
    slug:           slug,
    priceMonthly:   priceMonthly   ?? this.priceMonthly,
    isCustomPrice:  isCustomPrice  ?? this.isCustomPrice,
    maxProperties:  maxProperties  ?? this.maxProperties,
    maxUsers:       maxUsers       ?? this.maxUsers,
    maxRooms:       maxRooms       ?? this.maxRooms,
    maxTables:      maxTables      ?? this.maxTables,
    isHighlighted:  isHighlighted  ?? this.isHighlighted,
    isActive:       isActive       ?? this.isActive,
    sortOrder:      sortOrder,
  );

  /// Human-readable limit string — "Unlimited" when -1.
  static String limitLabel(int value) =>
      value == -1 ? 'Unlimited' : value.toString();
}

// ─── Service ──────────────────────────────────────────────────────────────────

class PlanService {
  final _db = Supabase.instance.client;

  /// Fetch all active plans ordered by sort_order (used on landing page).
  Future<List<PlanModel>> getActivePlans() async {
    final rows = await _db
        .from('plans')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows.map((r) => PlanModel.fromRow(r)).toList();
  }

  /// Active plans with each price overridden by the org's locked-in rate when
  /// one exists (rate-locked-for-life). Plans without a lock keep the live
  /// price. Use this on org-scoped screens (upgrade, billing) so customers see —
  /// and are charged — their locked rate. The charged amount is recomputed
  /// server-side in payhere-hash from the same locked book, so they stay in sync.
  Future<List<PlanModel>> getActivePlansForOrg(String orgId) async {
    final plans = await getActivePlans();
    final locked = await _db
        .from('org_locked_prices')
        .select('plan_slug, price_monthly')
        .eq('org_id', orgId);
    if ((locked as List).isEmpty) return plans;
    final lockedBySlug = <String, double>{
      for (final r in locked)
        r['plan_slug'] as String: (r['price_monthly'] as num).toDouble(),
    };
    return plans
        .map((p) => lockedBySlug.containsKey(p.slug)
            ? p.copyWith(priceMonthly: lockedBySlug[p.slug])
            : p)
        .toList();
  }

  /// Fetch ALL plans including inactive (superadmin only).
  Future<List<PlanModel>> getAllPlans() async {
    final rows = await _db
        .from('plans')
        .select()
        .order('sort_order', ascending: true);
    return rows.map((r) => PlanModel.fromRow(r)).toList();
  }

  /// Upsert a plan (superadmin only).
  Future<void> savePlan(PlanModel plan) async {
    await _db.from('plans').upsert({
      'id':              plan.id,
      'name':            plan.name,
      'slug':            plan.slug,
      'price_monthly':   plan.priceMonthly,
      'is_custom_price': plan.isCustomPrice,
      'max_properties':  plan.maxProperties,
      'max_users':       plan.maxUsers,
      'max_rooms':       plan.maxRooms,
      'max_tables':      plan.maxTables,
      'is_highlighted':  plan.isHighlighted,
      'is_active':       plan.isActive,
      'updated_at':      DateTime.now().toIso8601String(),
    });
  }
}
