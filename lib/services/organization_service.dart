import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

SupabaseClient get _db => Supabase.instance.client;

// ─── Data models ─────────────────────────────────────────────────────────────

class Organization {
  final String id;
  final String name;
  final String slug;
  final String country;
  final String phone;
  final String logoUrl;
  final String plan;   // free | pro | enterprise
  final String status; // active | suspended
  final DateTime createdAt;

  Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.country,
    required this.phone,
    required this.logoUrl,
    required this.plan,
    required this.status,
    required this.createdAt,
  });

  factory Organization.fromRow(Map<String, dynamic> r) => Organization(
        id:        r['id']         as String,
        name:      r['name']       as String,
        slug:      r['slug']       as String,
        country:   r['country']    as String? ?? '',
        phone:     r['phone']      as String? ?? '',
        logoUrl:   r['logo_url']   as String? ?? '',
        plan:      r['plan']       as String? ?? 'free',
        status:    r['status']     as String? ?? 'active',
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  // For superadmin usage: property + member counts attached
  int get propertyCount => _propertyCount ?? 0;
  int? _propertyCount;
  int get memberCount => _memberCount ?? 0;
  int? _memberCount;

  Organization copyWithCounts({int? propertyCount, int? memberCount}) {
    final copy = Organization(
      id: id, name: name, slug: slug, country: country, phone: phone,
      logoUrl: logoUrl, plan: plan, status: status, createdAt: createdAt,
    );
    copy._propertyCount = propertyCount ?? _propertyCount;
    copy._memberCount   = memberCount   ?? _memberCount;
    return copy;
  }
}

class OrgProperty {
  final String id;
  final String orgId;
  final String name;
  final String type;   // hotel | restaurant | both
  final String address;
  final String city;
  final String country;
  final String phone;
  final String email;
  final String timezone;
  final String currency; // ISO 4217 code e.g. USD, EUR
  final String logoUrl;
  final String status;
  final DateTime createdAt;

  const OrgProperty({
    required this.id,
    required this.orgId,
    required this.name,
    required this.type,
    required this.address,
    required this.city,
    required this.country,
    required this.phone,
    required this.email,
    required this.timezone,
    required this.currency,
    required this.logoUrl,
    required this.status,
    required this.createdAt,
  });

  factory OrgProperty.fromRow(Map<String, dynamic> r) => OrgProperty(
        id:        r['id']         as String,
        orgId:     r['org_id']     as String? ?? '',
        name:      r['name']       as String,
        type:      r['type']       as String? ?? 'hotel',
        address:   r['address']    as String? ?? '',
        city:      r['city']       as String? ?? '',
        country:   r['country']    as String? ?? '',
        phone:     r['phone']      as String? ?? '',
        email:     r['email']      as String? ?? '',
        timezone:  r['timezone']   as String? ?? 'UTC',
        currency:  r['currency']   as String? ?? 'USD',
        logoUrl:   r['logo_url']   as String? ?? '',
        status:    r['status']     as String? ?? 'active',
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  bool get isHotel      => type == 'hotel' || type == 'both';
  bool get isRestaurant => type == 'restaurant' || type == 'both';
}

class OrgMember {
  final String id;
  final String orgId;
  final String userId;
  final String role;
  final String fullName;
  final String email;

  const OrgMember({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.role,
    required this.fullName,
    required this.email,
  });

  factory OrgMember.fromRow(Map<String, dynamic> r) => OrgMember(
        id:       r['id']        as String,
        orgId:    r['org_id']    as String,
        userId:   r['user_id']   as String,
        role:     r['role']      as String? ?? 'member',
        fullName: (r['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? '',
        email:    (r['profiles'] as Map<String, dynamic>?)?['email']     as String? ?? '',
      );
}

// ─── Currency helpers ─────────────────────────────────────────────────────────

class AppCurrency {
  final String code;
  final String name;
  final String symbol;
  const AppCurrency(this.code, this.name, this.symbol);
  @override
  String toString() => '$code – $name ($symbol)';
}

const kCurrencies = [
  AppCurrency('USD', 'US Dollar',            '\$'),
  AppCurrency('EUR', 'Euro',                 '€'),
  AppCurrency('GBP', 'British Pound',        '£'),
  AppCurrency('AUD', 'Australian Dollar',    'A\$'),
  AppCurrency('CAD', 'Canadian Dollar',      'C\$'),
  AppCurrency('CHF', 'Swiss Franc',          'CHF'),
  AppCurrency('JPY', 'Japanese Yen',         '¥'),
  AppCurrency('CNY', 'Chinese Yuan',         '¥'),
  AppCurrency('INR', 'Indian Rupee',         '₹'),
  AppCurrency('LKR', 'Sri Lankan Rupee',     'Rs'),
  AppCurrency('BRL', 'Brazilian Real',       'R\$'),
  AppCurrency('MXN', 'Mexican Peso',         'MX\$'),
  AppCurrency('SGD', 'Singapore Dollar',     'S\$'),
  AppCurrency('HKD', 'Hong Kong Dollar',     'HK\$'),
  AppCurrency('NZD', 'New Zealand Dollar',   'NZ\$'),
  AppCurrency('AED', 'UAE Dirham',           'د.إ'),
  AppCurrency('SAR', 'Saudi Riyal',          '﷼'),
  AppCurrency('MYR', 'Malaysian Ringgit',    'RM'),
  AppCurrency('THB', 'Thai Baht',            '฿'),
  AppCurrency('IDR', 'Indonesian Rupiah',    'Rp'),
  AppCurrency('PHP', 'Philippine Peso',      '₱'),
  AppCurrency('VND', 'Vietnamese Dong',      '₫'),
  AppCurrency('KRW', 'South Korean Won',     '₩'),
  AppCurrency('TRY', 'Turkish Lira',         '₺'),
  AppCurrency('RUB', 'Russian Ruble',        '₽'),
  AppCurrency('ZAR', 'South African Rand',   'R'),
  AppCurrency('EGP', 'Egyptian Pound',       'E£'),
  AppCurrency('PKR', 'Pakistani Rupee',      '₨'),
  AppCurrency('BDT', 'Bangladeshi Taka',     '৳'),
  AppCurrency('NOK', 'Norwegian Krone',      'kr'),
  AppCurrency('SEK', 'Swedish Krona',        'kr'),
  AppCurrency('DKK', 'Danish Krone',         'kr'),
];

String _currencySymbol(String code) =>
    kCurrencies.firstWhere((c) => c.code == code,
        orElse: () => const AppCurrency('USD', '', '\$')).symbol;

// ─── Plan limits ─────────────────────────────────────────────────────────────

const _maxProperties = {'free': 2, 'pro': 5, 'enterprise': -1};
const _maxStaff      = {'free': 5, 'pro': 20, 'enterprise': -1};

// ─── Service ─────────────────────────────────────────────────────────────────

class OrganizationService {
  OrganizationService._();
  static final OrganizationService _i = OrganizationService._();
  factory OrganizationService() => _i;

  static const _activePropertyKey = 'active_property_id';

  // ── Organization ────────────────────────────────────────────────────────────

  Future<Organization?> getMyOrganization() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _db
        .from('organization_members')
        .select('org_id, organizations(*)')
        .eq('user_id', userId)
        .limit(1);

    if (rows.isEmpty) return null;
    final orgData = rows.first['organizations'] as Map<String, dynamic>?;
    if (orgData == null) return null;
    return Organization.fromRow(orgData);
  }

  Future<Organization> createOrganization({
    required String name,
    required String slug,
    required String country,
    required String phone,
    String logoUrl = '',
  }) async {
    final userId = _db.auth.currentUser!.id;

    // Generate UUID client-side so we never need to SELECT the org before
    // adding the membership row. The SELECT policy requires org membership,
    // so we insert org + member atomically (same id), then fetch.
    final orgId = const Uuid().v4();

    await _db.from('organizations').insert({
      'id':       orgId,
      'name':     name,
      'slug':     slug,
      'country':  country,
      'phone':    phone,
      'logo_url': logoUrl,
    });

    // Add membership immediately — now current_org_id() returns orgId
    await _db.from('organization_members').insert({
      'org_id':  orgId,
      'user_id': userId,
      'role':    'owner',
    });

    // SELECT policy now passes (user is a member)
    final orgRow = await _db
        .from('organizations')
        .select()
        .eq('id', orgId)
        .single();

    return Organization.fromRow(orgRow);
  }

  // ── Properties ──────────────────────────────────────────────────────────────

  /// Returns all properties the current user has access to (via property_staff
  /// or hotel_users legacy system).
  ///
  /// Uses a two-step approach: first collect IDs, then fetch hotel rows.
  /// This avoids relying on PostgREST FK-join (hotels(*)) which can silently
  /// return null when the schema cache is stale after a migration.
  Future<List<OrgProperty>> getMyProperties() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final ids = <String>{};

    // 1. property_staff (new system — one row per assigned property)
    try {
      final rows = await _db
          .from('property_staff')
          .select('property_id')
          .eq('user_id', userId);
      for (final r in rows) {
        final id = r['property_id'] as String?;
        if (id != null) ids.add(id);
      }
    } catch (_) {}

    // 2. hotel_users (legacy system)
    try {
      final rows = await _db
          .from('hotel_users')
          .select('hotel_id')
          .eq('user_id', userId);
      for (final r in rows) {
        final id = r['hotel_id'] as String?;
        if (id != null) ids.add(id);
      }
    } catch (_) {}

    if (ids.isEmpty) return [];

    // 3. Fetch hotel details for all collected IDs in one query
    final hotels = await _db
        .from('hotels')
        .select()
        .inFilter('id', ids.toList());

    return hotels.map((h) => OrgProperty.fromRow(h)).toList();
  }

  Future<OrgProperty> addProperty({
    required String orgId,
    required String name,
    required String type,
    required String address,
    required String city,
    required String country,
    required String phone,
    required String email,
    required String timezone,
    String currency = 'USD',
    String logoUrl = '',
  }) async {
    final userId = _db.auth.currentUser!.id;

    // slug from name
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    final row = await _db
        .from('hotels')
        .insert({
          'name':     name,
          'slug':     '$slug-${DateTime.now().millisecondsSinceEpoch}',
          'org_id':   orgId,
          'type':     type,
          'address':  address,
          'city':     city,
          'country':  country,
          'phone':    phone,
          'email':    email,
          'timezone': timezone,
          'currency': currency,
          'logo_url': logoUrl,
          'status':   'active',
        })
        .select()
        .single();

    final property = OrgProperty.fromRow(row);

    // Add creator to property_staff as owner
    await _db.from('property_staff').insert({
      'property_id': property.id,
      'user_id':     userId,
      'role':        'owner',
    });

    // Also add to hotel_users for backward compat with existing screens
    await _db.from('hotel_users').insert({
      'hotel_id': property.id,
      'user_id':  userId,
      'role':     'owner',
    }).onError((_, __) => []);  // ignore if already exists

    // Seed hotel_settings for existing screens
    await _db.from('hotel_settings').upsert({
      'hotel_id':        property.id,
      'display_name':    name,
      'address':         address,
      'phone':           phone,
      'email':           email,
      'currency_symbol': _currencySymbol(currency),
    }, onConflict: 'hotel_id');

    return property;
  }

  // ── Active property (persisted locally) ─────────────────────────────────────

  Future<String?> getActivePropertyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activePropertyKey);
  }

  Future<void> setActivePropertyId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activePropertyKey, id);
  }

  Future<OrgProperty?> getActiveProperty() async {
    final id = await getActivePropertyId();
    if (id == null) return null;
    try {
      final row = await _db.from('hotels').select().eq('id', id).single();
      return OrgProperty.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  // ── Members ──────────────────────────────────────────────────────────────────

  Future<List<OrgMember>> getOrganizationMembers(String orgId) async {
    final rows = await _db
        .from('organization_members')
        .select('*, profiles(full_name, email)')
        .eq('org_id', orgId);

    return rows.map((r) => OrgMember.fromRow(r)).toList();
  }

  Future<void> inviteMember(String orgId, String email, String role) async {
    // In a real system this would send an invite email via Supabase Edge Function.
    // For now we look up by email and add directly if user exists.
    final userRows = await _db
        .from('profiles')
        .select('id')
        .eq('email', email)
        .limit(1);

    if (userRows.isEmpty) {
      throw Exception('No user found with that email. Ask them to sign up first.');
    }

    await _db.from('organization_members').insert({
      'org_id':  orgId,
      'user_id': userRows.first['id'] as String,
      'role':    role,
    });
  }

  // ── Plan limits ──────────────────────────────────────────────────────────────

  Future<bool> canAddProperty(String orgId) async {
    // TODO: Uncomment to enforce pro/enterprise plan limits
    return true;

    // final orgRows = await _db
    //     .from('organizations')
    //     .select('plan')
    //     .eq('id', orgId)
    //     .single();

    // final plan  = orgRows['plan'] as String? ?? 'free';
    // final limit = _maxProperties[plan] ?? 1;
    // if (limit == -1) return true; // enterprise unlimited

    // final count = await _db
    //     .from('hotels')
    //     .select('id')
    //     .eq('org_id', orgId)
    //     .count();

    // return count.count < limit;
  }

  Future<bool> canAddStaff(String orgId) async {
    // TODO: Uncomment to enforce pro/enterprise plan limits
    return true;

    // final orgRows = await _db
    //     .from('organizations')
    //     .select('plan')
    //     .eq('id', orgId)
    //     .single();

    // final plan  = orgRows['plan'] as String? ?? 'free';
    // final limit = _maxStaff[plan] ?? 5;
    // if (limit == -1) return true;

    // final count = await _db
    //     .from('organization_members')
    //     .select('id')
    //     .eq('org_id', orgId)
    //     .count();

    // return count.count < limit;
  }

  // ── Superadmin queries ───────────────────────────────────────────────────────

  Future<List<Organization>> getAllOrganizations() async {
    final rows = await _db
        .from('organizations')
        .select()
        .order('created_at', ascending: false);

    final orgs = rows.map((r) => Organization.fromRow(r)).toList();

    // Attach counts
    final result = <Organization>[];
    for (final org in orgs) {
      final propCount = await _db
          .from('hotels')
          .select('id')
          .eq('org_id', org.id)
          .count();
      final memberCount = await _db
          .from('organization_members')
          .select('id')
          .eq('org_id', org.id)
          .count();
      result.add(org.copyWithCounts(
        propertyCount: propCount.count,
        memberCount:   memberCount.count,
      ));
    }
    return result;
  }

  Future<List<OrgProperty>> getOrgProperties(String orgId) async {
    final rows = await _db
        .from('hotels')
        .select()
        .eq('org_id', orgId)
        .order('created_at');
    return rows.map((r) => OrgProperty.fromRow(r)).toList();
  }

  Future<void> updateOrgStatus(String orgId, String status) async {
    await _db
        .from('organizations')
        .update({'status': status})
        .eq('id', orgId);
  }

  // ── Property management ──────────────────────────────────────────────────────

  /// Sets a property's status (active | inactive).
  Future<void> updatePropertyStatus(String propertyId, String status) async {
    await _db
        .from('hotels')
        .update({'status': status})
        .eq('id', propertyId);
  }

  /// Permanently deletes a property and all its membership/settings rows.
  /// Uses a SECURITY DEFINER RPC to bypass RLS on related tables.
  Future<void> deleteProperty(String propertyId) async {
    await _db.rpc('delete_property', params: {'p_property_id': propertyId});
  }
}
