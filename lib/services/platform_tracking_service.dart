import 'package:supabase_flutter/supabase_flutter.dart';

import 'organization_service.dart';

// Superadmin views of the whole platform: companies, properties and the totals.
// Backed by supabase/migrations/20261023000004_superadmin_companies_properties.sql.
// Parsing is tolerant, like user_tracking_service.dart: a missing or oddly typed
// field becomes an empty value instead of an exception.

DateTime? _t(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
String _s(Object? v) => v is String ? v : '';
int _i(Object? v) => v is num ? v.toInt() : 0;
double _d(Object? v) => v is num ? v.toDouble() : 0;
bool _b(Object? v) => v is bool && v;
Map<String, dynamic> _m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _l(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];
Map<String, int> _counts(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key as String: _i(e.value)} : const {};

class DayPoint {
  const DayPoint({required this.day, required this.signups, required this.signIns, required this.actions});

  factory DayPoint.fromJson(Map<String, dynamic> j) => DayPoint(
        day: _t(j['day']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        signups: _i(j['signups']),
        signIns: _i(j['sign_ins']),
        actions: _i(j['actions']),
      );

  final DateTime day;
  final int signups;
  final int signIns;
  final int actions;
}

class OrgRef {
  const OrgRef({required this.orgId, required this.name, this.value = 0, this.at});

  factory OrgRef.fromJson(Map<String, dynamic> j) =>
      OrgRef(orgId: _s(j['org_id']), name: _s(j['name']), value: _i(j['actions']), at: _t(j['trial_ends_at']));

  final String orgId;
  final String name;

  /// Actions in 30 days, for the busiest list.
  final int value;

  /// Trial end, for the trials-ending list.
  final DateTime? at;
}

class PlatformOverview {
  const PlatformOverview({
    this.companies = 0,
    this.companiesDeleted = 0,
    this.companiesNew30d = 0,
    this.companiesByStatus = const {},
    this.companiesByPlan = const {},
    this.dormant30d = 0,
    this.properties = 0,
    this.propertiesActive = 0,
    this.propertiesNew30d = 0,
    this.propertiesByType = const {},
    this.users = 0,
    this.usersActive7d = 0,
    this.rooms = 0,
    this.tables = 0,
    this.bookings = 0,
    this.bookings30d = 0,
    this.paidValue30d = 0,
    this.orders = 0,
    this.orders30d = 0,
    this.paidCount = 0,
    this.paidAmount = 0,
    this.paid30d = 0,
    this.pendingPayments = 0,
    this.actions24h = 0,
    this.actions7d = 0,
    this.daily = const [],
    this.busiest = const [],
    this.trialsEnding = const [],
  });

  factory PlatformOverview.fromJson(Map<String, dynamic> j) {
    final c = _m(j['companies']);
    final p = _m(j['properties']);
    final u = _m(j['users']);
    final inv = _m(j['inventory']);
    final b = _m(j['bookings']);
    final o = _m(j['orders']);
    final s = _m(j['subscriptions']);
    final a = _m(j['activity']);
    return PlatformOverview(
      companies: _i(c['total']),
      companiesDeleted: _i(c['deleted']),
      companiesNew30d: _i(c['new_30d']),
      companiesByStatus: _counts(c['by_status']),
      companiesByPlan: _counts(c['by_plan']),
      dormant30d: _i(c['dormant_30d']),
      properties: _i(p['total']),
      propertiesActive: _i(p['active']),
      propertiesNew30d: _i(p['new_30d']),
      propertiesByType: _counts(p['by_type']),
      users: _i(u['total']),
      usersActive7d: _i(u['active_7d']),
      rooms: _i(inv['rooms']),
      tables: _i(inv['tables']),
      bookings: _i(b['total']),
      bookings30d: _i(b['last_30d']),
      paidValue30d: _d(b['paid_value_30d']),
      orders: _i(o['total']),
      orders30d: _i(o['last_30d']),
      paidCount: _i(s['paid_count']),
      paidAmount: _d(s['paid_amount']),
      paid30d: _d(s['paid_30d']),
      pendingPayments: _i(s['pending']),
      actions24h: _i(a['actions_24h']),
      actions7d: _i(a['actions_7d']),
      daily: _l(a['daily']).map(DayPoint.fromJson).toList(),
      busiest: _l(j['busiest_companies']).map(OrgRef.fromJson).toList(),
      trialsEnding: _l(j['trials_ending']).map(OrgRef.fromJson).toList(),
    );
  }

  final int companies;
  final int companiesDeleted;
  final int companiesNew30d;
  final Map<String, int> companiesByStatus;
  final Map<String, int> companiesByPlan;
  final int dormant30d;
  final int properties;
  final int propertiesActive;
  final int propertiesNew30d;
  final Map<String, int> propertiesByType;
  final int users;
  final int usersActive7d;
  final int rooms;
  final int tables;
  final int bookings;
  final int bookings30d;
  final double paidValue30d;
  final int orders;
  final int orders30d;
  final int paidCount;
  final double paidAmount;
  final double paid30d;
  final int pendingPayments;
  final int actions24h;
  final int actions7d;
  final List<DayPoint> daily;
  final List<OrgRef> busiest;
  final List<OrgRef> trialsEnding;
}

class CompanySummary {
  const CompanySummary({
    required this.orgId,
    required this.name,
    required this.slug,
    required this.plan,
    required this.status,
    required this.country,
    required this.phone,
    required this.email,
    required this.createdAt,
    required this.trialEndsAt,
    required this.billingCycle,
    required this.subscriptionPaidAt,
    required this.logoUrl,
    required this.customPriceMonthly,
    required this.customPriceAnnually,
    required this.isDeleted,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.members,
    required this.properties,
    required this.rooms,
    required this.tables,
    required this.bookings30d,
    required this.orders30d,
    required this.actions30d,
    required this.lastActivityAt,
    required this.lastSignInAt,
  });

  factory CompanySummary.fromJson(Map<String, dynamic> j) => CompanySummary(
        orgId: _s(j['org_id']),
        name: _s(j['name']),
        slug: _s(j['slug']),
        plan: _s(j['plan']),
        status: _s(j['status']),
        country: _s(j['country']),
        phone: _s(j['phone']),
        email: _s(j['email']),
        createdAt: _t(j['created_at']),
        trialEndsAt: _t(j['trial_ends_at']),
        billingCycle: j['billing_cycle'] as String?,
        subscriptionPaidAt: _t(j['subscription_paid_at']),
        logoUrl: _s(j['logo_url']),
        customPriceMonthly: j['custom_price_monthly'] is num ? (j['custom_price_monthly'] as num).toDouble() : null,
        customPriceAnnually: j['custom_price_annually'] is num ? (j['custom_price_annually'] as num).toDouble() : null,
        isDeleted: _b(j['is_deleted']),
        ownerId: _s(j['owner_id']),
        ownerName: _s(j['owner_name']),
        ownerEmail: _s(j['owner_email']),
        members: _i(j['members']),
        properties: _i(j['properties']),
        rooms: _i(j['rooms']),
        tables: _i(j['tables']),
        bookings30d: _i(j['bookings_30d']),
        orders30d: _i(j['orders_30d']),
        actions30d: _i(j['actions_30d']),
        lastActivityAt: _t(j['last_activity_at']),
        lastSignInAt: _t(j['last_sign_in_at']),
      );

  final String orgId;
  final String name;
  final String slug;
  final String plan;

  /// The real status: "trialing" past its deadline reads "trial_expired".
  final String status;
  final String country;
  final String phone;
  final String email;
  final DateTime? createdAt;
  final DateTime? trialEndsAt;
  final String? billingCycle;
  final DateTime? subscriptionPaidAt;
  final String logoUrl;
  final double? customPriceMonthly;
  final double? customPriceAnnually;
  final bool isDeleted;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final int members;
  final int properties;
  final int rooms;
  final int tables;
  final int bookings30d;
  final int orders30d;
  final int actions30d;
  final DateTime? lastActivityAt;
  final DateTime? lastSignInAt;

  String get ownerLabel => ownerName.isNotEmpty ? ownerName : (ownerEmail.endsWith('@staff.internal') ? '' : ownerEmail);

  /// For the existing company dialog, which takes the old model.
  Organization toOrganization() => Organization.fromRow({
        'id': orgId,
        'name': name,
        'slug': slug,
        'country': country,
        'phone': phone,
        'logo_url': logoUrl,
        'plan': plan,
        // The stored status, not the effective one: the dialog derives the
        // effective state itself from trial_ends_at.
        'status': status == 'trial_expired' ? 'trialing' : status,
        'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
        'trial_ends_at': trialEndsAt?.toUtc().toIso8601String(),
        'custom_price_monthly': customPriceMonthly,
        'custom_price_annually': customPriceAnnually,
        'billing_cycle': billingCycle,
        'subscription_paid_at': subscriptionPaidAt?.toUtc().toIso8601String(),
      }).copyWithCounts(propertyCount: properties, memberCount: members);
}

class CompanyPage {
  const CompanyPage({required this.companies, required this.total});

  final List<CompanySummary> companies;
  final int total;
}

class Limit {
  const Limit({required this.max, required this.used});

  factory Limit.fromJson(Map<String, dynamic> j) => Limit(max: j['max'] is num ? (j['max'] as num).toInt() : null, used: _i(j['used']));

  /// Null when the plan has no cap on this; -1 is also "unlimited" in the plans table.
  final int? max;
  final int used;

  bool get unlimited => max == null || max! < 0;
  bool get over => !unlimited && used > max!;
  double get fraction => unlimited || max == 0 ? 0 : (used / max!).clamp(0, 1).toDouble();
}

class MemberRow {
  const MemberRow({required this.userId, required this.name, required this.email, required this.username, required this.role, this.joined, this.lastSignInAt, this.actions30d = 0, this.canManageBilling = false});

  factory MemberRow.fromJson(Map<String, dynamic> j) => MemberRow(
        userId: _s(j['user_id']),
        name: _s(j['name']),
        email: _s(j['email']),
        username: _s(j['username']),
        role: _s(j['role']),
        joined: _t(j['joined']),
        lastSignInAt: _t(j['last_sign_in_at']),
        actions30d: _i(j['actions_30d']),
        canManageBilling: _b(j['can_manage_billing']),
      );

  final String userId;
  final String name;
  final String email;
  final String username;
  final String role;
  final DateTime? joined;
  final DateTime? lastSignInAt;
  final int actions30d;
  final bool canManageBilling;

  bool get hasRealEmail => email.isNotEmpty && !email.endsWith('@staff.internal');
  String get display => name.isNotEmpty ? name : (username.isNotEmpty ? username : (hasRealEmail ? email : 'Unnamed user'));
}

class PropertyRow {
  const PropertyRow({required this.propertyId, required this.name, required this.type, required this.city, required this.country, required this.status, this.createdAt, this.rooms = 0, this.tables = 0, this.bookings30d = 0, this.orders30d = 0, this.lastActivityAt});

  factory PropertyRow.fromJson(Map<String, dynamic> j) => PropertyRow(
        propertyId: _s(j['property_id']),
        name: _s(j['name']),
        type: _s(j['type']),
        city: _s(j['city']),
        country: _s(j['country']),
        status: _s(j['status']),
        createdAt: _t(j['created_at']),
        rooms: _i(j['rooms']),
        tables: _i(j['tables']),
        bookings30d: _i(j['bookings_30d']),
        orders30d: _i(j['orders_30d']),
        lastActivityAt: _t(j['last_activity_at']),
      );

  final String propertyId;
  final String name;
  final String type;
  final String city;
  final String country;
  final String status;
  final DateTime? createdAt;
  final int rooms;
  final int tables;
  final int bookings30d;
  final int orders30d;
  final DateTime? lastActivityAt;
}

class PaymentRow {
  const PaymentRow({required this.id, required this.plan, required this.cycle, required this.amount, required this.currency, required this.status, this.createdAt, this.payer = ''});

  factory PaymentRow.fromJson(Map<String, dynamic> j) => PaymentRow(
        id: _s(j['id']),
        plan: _s(j['plan']),
        cycle: _s(j['cycle']),
        amount: _d(j['amount']),
        currency: _s(j['currency']),
        status: _s(j['status']),
        createdAt: _t(j['created_at']),
        payer: _s(j['payer']),
      );

  final String id;
  final String plan;
  final String cycle;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final String payer;
}

class ActionTally {
  const ActionTally(this.action, this.count);
  final String action;
  final int count;
}

class CompanyInsight {
  const CompanyInsight({
    required this.orgId,
    required this.name,
    required this.plan,
    required this.status,
    required this.country,
    required this.phone,
    required this.email,
    required this.createdAt,
    required this.createdByName,
    required this.createdByEmail,
    required this.trialEndsAt,
    required this.billingCycle,
    required this.subscriptionPaidAt,
    required this.limits,
    required this.totals,
    required this.members,
    required this.properties,
    required this.payments,
    required this.activityCounts,
    required this.activityTotal,
    required this.firstActivityAt,
    required this.lastActivityAt,
  });

  factory CompanyInsight.fromJson(Map<String, dynamic> j) {
    final lim = _m(j['limits']);
    return CompanyInsight(
      orgId: _s(j['org_id']),
      name: _s(j['name']),
      plan: _s(j['plan']),
      status: _s(j['status']),
      country: _s(j['country']),
      phone: _s(j['phone']),
      email: _s(j['email']),
      createdAt: _t(j['created_at']),
      createdByName: _s(j['created_by_name']),
      createdByEmail: _s(j['created_by_email']),
      trialEndsAt: _t(j['trial_ends_at']),
      billingCycle: _s(j['billing_cycle']),
      subscriptionPaidAt: _t(j['subscription_paid_at']),
      limits: {for (final k in const ['properties', 'users', 'rooms', 'tables']) k: Limit.fromJson(_m(lim[k]))},
      totals: _m(j['totals']),
      members: _l(j['members']).map(MemberRow.fromJson).toList(),
      properties: _l(j['properties']).map(PropertyRow.fromJson).toList(),
      payments: _l(j['payments']).map(PaymentRow.fromJson).toList(),
      activityCounts: _l(j['activity_counts']).map((e) => ActionTally(_s(e['action']), _i(e['n']))).toList(),
      activityTotal: _i(j['activity_total']),
      firstActivityAt: _t(j['first_activity_at']),
      lastActivityAt: _t(j['last_activity_at']),
    );
  }

  final String orgId;
  final String name;
  final String plan;
  final String status;
  final String country;
  final String phone;
  final String email;
  final DateTime? createdAt;
  final String createdByName;
  final String createdByEmail;
  final DateTime? trialEndsAt;
  final String billingCycle;
  final DateTime? subscriptionPaidAt;
  final Map<String, Limit> limits;
  final Map<String, dynamic> totals;
  final List<MemberRow> members;
  final List<PropertyRow> properties;
  final List<PaymentRow> payments;
  final List<ActionTally> activityCounts;
  final int activityTotal;
  final DateTime? firstActivityAt;
  final DateTime? lastActivityAt;

  num total(String k) => totals[k] is num ? totals[k] as num : 0;
}

class PropertySummary {
  const PropertySummary({
    required this.propertyId,
    required this.orgId,
    required this.orgName,
    required this.orgPlan,
    required this.orgStatus,
    required this.name,
    required this.type,
    required this.city,
    required this.country,
    required this.status,
    required this.currency,
    required this.isDeleted,
    required this.createdAt,
    required this.rooms,
    required this.tables,
    required this.staff,
    required this.bookingsTotal,
    required this.bookings30d,
    required this.orders30d,
    required this.paidValue30d,
    required this.actions30d,
    required this.lastActivityAt,
  });

  factory PropertySummary.fromJson(Map<String, dynamic> j) => PropertySummary(
        propertyId: _s(j['property_id']),
        orgId: _s(j['org_id']),
        orgName: _s(j['org_name']),
        orgPlan: _s(j['org_plan']),
        orgStatus: _s(j['org_status']),
        name: _s(j['name']),
        type: _s(j['type']),
        city: _s(j['city']),
        country: _s(j['country']),
        status: _s(j['status']),
        currency: _s(j['currency']),
        isDeleted: _b(j['is_deleted']),
        createdAt: _t(j['created_at']),
        rooms: _i(j['rooms']),
        tables: _i(j['tables']),
        staff: _i(j['staff']),
        bookingsTotal: _i(j['bookings_total']),
        bookings30d: _i(j['bookings_30d']),
        orders30d: _i(j['orders_30d']),
        paidValue30d: _d(j['paid_value_30d']),
        actions30d: _i(j['actions_30d']),
        lastActivityAt: _t(j['last_activity_at']),
      );

  final String propertyId;
  final String orgId;
  final String orgName;
  final String orgPlan;
  final String orgStatus;
  final String name;
  final String type;
  final String city;
  final String country;
  final String status;
  final String currency;
  final bool isDeleted;
  final DateTime? createdAt;
  final int rooms;
  final int tables;
  final int staff;
  final int bookingsTotal;
  final int bookings30d;
  final int orders30d;
  final double paidValue30d;
  final int actions30d;
  final DateTime? lastActivityAt;

  String get place => [city, country].where((p) => p.isNotEmpty).join(', ');
}

class PropertyPage {
  const PropertyPage({required this.properties, required this.total});

  final List<PropertySummary> properties;
  final int total;
}

class BookingRow {
  const BookingRow({required this.ref, required this.status, this.checkIn, this.checkOut, this.amount = 0, this.paid = false, this.source = '', this.createdAt});

  factory BookingRow.fromJson(Map<String, dynamic> j) => BookingRow(
        ref: _s(j['ref']),
        status: _s(j['status']),
        checkIn: _t(j['check_in']),
        checkOut: _t(j['check_out']),
        amount: _d(j['amount']),
        paid: _b(j['paid']),
        source: _s(j['source']),
        createdAt: _t(j['created_at']),
      );

  final String ref;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double amount;
  final bool paid;
  final String source;
  final DateTime? createdAt;
}

class OrderRow {
  const OrderRow({required this.number, required this.status, required this.type, required this.paymentStatus, required this.room, required this.items, this.createdAt});

  factory OrderRow.fromJson(Map<String, dynamic> j) => OrderRow(
        number: _s(j['number']),
        status: _s(j['status']),
        type: _s(j['type']),
        paymentStatus: _s(j['payment_status']),
        room: _s(j['room']),
        items: _i(j['items']),
        createdAt: _t(j['created_at']),
      );

  final String number;
  final String status;
  final String type;
  final String paymentStatus;
  final String room;
  final int items;
  final DateTime? createdAt;
}

class PropertyInsight {
  const PropertyInsight({
    required this.propertyId,
    required this.name,
    required this.slug,
    required this.type,
    required this.address,
    required this.city,
    required this.country,
    required this.phone,
    required this.email,
    required this.timezone,
    required this.currency,
    required this.status,
    required this.isDeleted,
    required this.createdAt,
    required this.bookingChannels,
    required this.orgId,
    required this.orgName,
    required this.orgPlan,
    required this.orgStatus,
    required this.settings,
    required this.roomsByStatus,
    required this.tablesByStatus,
    required this.bookingsByStatus,
    required this.ordersByStatus,
    required this.totals,
    required this.expensesByCategory,
    required this.staff,
    required this.companyAccess,
    required this.recentBookings,
    required this.recentOrders,
    required this.activityCounts,
    required this.activityTotal,
    required this.firstActivityAt,
    required this.lastActivityAt,
  });

  factory PropertyInsight.fromJson(Map<String, dynamic> j) {
    final c = _m(j['company']);
    return PropertyInsight(
      propertyId: _s(j['property_id']),
      name: _s(j['name']),
      slug: _s(j['slug']),
      type: _s(j['type']),
      address: _s(j['address']),
      city: _s(j['city']),
      country: _s(j['country']),
      phone: _s(j['phone']),
      email: _s(j['email']),
      timezone: _s(j['timezone']),
      currency: _s(j['currency']),
      status: _s(j['status']),
      isDeleted: _b(j['is_deleted']),
      createdAt: _t(j['created_at']),
      bookingChannels: j['booking_channels'] is List ? [for (final e in j['booking_channels'] as List) if (e is String) e] : const [],
      orgId: _s(c['org_id']),
      orgName: _s(c['name']),
      orgPlan: _s(c['plan']),
      orgStatus: _s(c['status']),
      settings: _m(j['settings']),
      roomsByStatus: _counts(j['rooms_by_status']),
      tablesByStatus: _counts(j['tables_by_status']),
      bookingsByStatus: _counts(j['bookings_by_status']),
      ordersByStatus: _counts(j['orders_by_status']),
      totals: _m(j['totals']),
      expensesByCategory: {for (final e in _l(j['expenses_by_category'])) _s(e['category']): _d(e['amount'])},
      staff: _l(j['staff']).map(MemberRow.fromJson).toList(),
      companyAccess: _l(j['company_access']).map(MemberRow.fromJson).toList(),
      recentBookings: _l(j['recent_bookings']).map(BookingRow.fromJson).toList(),
      recentOrders: _l(j['recent_orders']).map(OrderRow.fromJson).toList(),
      activityCounts: _l(j['activity_counts']).map((e) => ActionTally(_s(e['action']), _i(e['n']))).toList(),
      activityTotal: _i(j['activity_total']),
      firstActivityAt: _t(j['first_activity_at']),
      lastActivityAt: _t(j['last_activity_at']),
    );
  }

  final String propertyId;
  final String name;
  final String slug;
  final String type;
  final String address;
  final String city;
  final String country;
  final String phone;
  final String email;
  final String timezone;
  final String currency;
  final String status;
  final bool isDeleted;
  final DateTime? createdAt;
  final List<String> bookingChannels;
  final String orgId;
  final String orgName;
  final String orgPlan;
  final String orgStatus;
  final Map<String, dynamic> settings;
  final Map<String, int> roomsByStatus;
  final Map<String, int> tablesByStatus;
  final Map<String, int> bookingsByStatus;
  final Map<String, int> ordersByStatus;
  final Map<String, dynamic> totals;
  final Map<String, double> expensesByCategory;
  final List<MemberRow> staff;
  final List<MemberRow> companyAccess;
  final List<BookingRow> recentBookings;
  final List<OrderRow> recentOrders;
  final List<ActionTally> activityCounts;
  final int activityTotal;
  final DateTime? firstActivityAt;
  final DateTime? lastActivityAt;

  num total(String k) => totals[k] is num ? totals[k] as num : 0;
}

/// Superadmin-only reads. Every call goes through a SECURITY DEFINER function that
/// refuses anyone else, so this holds no permission logic.
class PlatformTrackingService {
  PlatformTrackingService([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<PlatformOverview> overview() async {
    final r = await _db.rpc('superadmin_platform_overview');
    return PlatformOverview.fromJson(_m(r));
  }

  Future<CompanyPage> listCompanies({String search = '', String filter = 'all', int limit = 25, int offset = 0}) async {
    final rows = await _db.rpc('superadmin_list_companies',
        params: {'p_search': search, 'p_filter': filter, 'p_limit': limit, 'p_offset': offset});
    final list = _l(rows);
    return CompanyPage(
      companies: list.map(CompanySummary.fromJson).toList(),
      total: list.isEmpty ? 0 : _i(list.first['total_count']),
    );
  }

  Future<CompanyInsight> companyDetail(String orgId) async {
    final r = await _db.rpc('superadmin_company_detail', params: {'p_org_id': orgId});
    return CompanyInsight.fromJson(_m(r));
  }

  Future<PropertyPage> listProperties({String search = '', String filter = 'all', String? orgId, int limit = 25, int offset = 0}) async {
    final rows = await _db.rpc('superadmin_list_properties',
        params: {'p_search': search, 'p_filter': filter, 'p_org_id': orgId, 'p_limit': limit, 'p_offset': offset});
    final list = _l(rows);
    return PropertyPage(
      properties: list.map(PropertySummary.fromJson).toList(),
      total: list.isEmpty ? 0 : _i(list.first['total_count']),
    );
  }

  Future<PropertyInsight> propertyDetail(String propertyId) async {
    final r = await _db.rpc('superadmin_property_detail', params: {'p_property_id': propertyId});
    return PropertyInsight.fromJson(_m(r));
  }
}
