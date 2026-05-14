import 'dart:typed_data';
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
  final String plan;   // free | starter | pro | enterprise
  final String status; // active | suspended
  final DateTime createdAt;

  // Custom pricing — set by superadmin for enterprise customers.
  // null = not yet agreed / not applicable.
  final double? customPriceMonthly;
  final double? customPriceAnnually;
  final String? billingCycle; // 'monthly' | 'annually'

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
    this.customPriceMonthly,
    this.customPriceAnnually,
    this.billingCycle,
  });

  factory Organization.fromRow(Map<String, dynamic> r) => Organization(
        id:                  r['id']                    as String,
        name:                r['name']                  as String,
        slug:                r['slug']                  as String,
        country:             r['country']               as String? ?? '',
        phone:               r['phone']                 as String? ?? '',
        logoUrl:             r['logo_url']              as String? ?? '',
        plan:                r['plan']                  as String? ?? 'free',
        status:              r['status']                as String? ?? 'active',
        createdAt:           DateTime.parse(r['created_at'] as String),
        customPriceMonthly:  (r['custom_price_monthly']  as num?)?.toDouble(),
        customPriceAnnually: (r['custom_price_annually'] as num?)?.toDouble(),
        billingCycle:        r['billing_cycle']          as String?,
      );

  // For superadmin usage: property + member counts attached
  int get propertyCount => _propertyCount ?? 0;
  int? _propertyCount;
  int get memberCount => _memberCount ?? 0;
  int? _memberCount;

  /// Effective custom price based on billing cycle. null if no custom price is set.
  double? get effectiveCustomPrice {
    if (billingCycle == 'annually') return customPriceAnnually;
    return customPriceMonthly;
  }

  /// True when this org has an enterprise plan with a custom price configured.
  bool get hasCustomSubscription =>
      plan == 'enterprise' && (effectiveCustomPrice ?? 0) > 0;

  Organization copyWithCounts({int? propertyCount, int? memberCount}) {
    final copy = Organization(
      id: id, name: name, slug: slug, country: country, phone: phone,
      logoUrl: logoUrl, plan: plan, status: status, createdAt: createdAt,
      customPriceMonthly: customPriceMonthly,
      customPriceAnnually: customPriceAnnually,
      billingCycle: billingCycle,
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
  final String primaryColor; // hex e.g. '#D4A853'
  final DateTime createdAt;
  /// Active booking channels e.g. ['bookingCom', 'airbnb', 'direct']
  final List<String> bookingChannels;

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
    this.primaryColor = '#D4A853',
    required this.createdAt,
    this.bookingChannels = const ['direct'],
  });

  factory OrgProperty.fromRow(Map<String, dynamic> r) => OrgProperty(
        id:           r['id']            as String,
        orgId:        r['org_id']        as String? ?? '',
        name:         r['name']          as String,
        type:         r['type']          as String? ?? 'hotel',
        address:      r['address']       as String? ?? '',
        city:         r['city']          as String? ?? '',
        country:      r['country']       as String? ?? '',
        phone:        r['phone']         as String? ?? '',
        email:        r['email']         as String? ?? '',
        timezone:     r['timezone']      as String? ?? 'UTC',
        currency:     r['currency']      as String? ?? 'USD',
        logoUrl:      r['logo_url']      as String? ?? '',
        status:       r['status']        as String? ?? 'active',
        primaryColor: r['primary_color'] as String? ?? '#D4A853',
        createdAt:    DateTime.parse(r['created_at'] as String),
        bookingChannels: (r['booking_channels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['direct'],
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
  final bool canManageBilling;

  const OrgMember({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.role,
    required this.fullName,
    required this.email,
    this.canManageBilling = false,
  });

  factory OrgMember.fromRow(Map<String, dynamic> r) => OrgMember(
        id:               r['id']                 as String,
        orgId:            r['org_id']             as String,
        userId:           r['user_id']            as String,
        role:             r['role']               as String? ?? 'member',
        fullName:         (r['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? '',
        email:            (r['profiles'] as Map<String, dynamic>?)?['email']     as String? ?? '',
        canManageBilling: r['can_manage_billing'] as bool? ?? false,
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

// (Plan limits are fetched dynamically from the `plans` table)

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

    // Primary path: SECURITY DEFINER RPC that bypasses all RLS policies.
    // Works regardless of which migration set is active.
    try {
      final rows = await _db.rpc('get_my_properties');
      if (rows is List && rows.isNotEmpty) {
        return rows.map((h) => OrgProperty.fromRow(h as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // ── Fallback (if RPC not yet deployed) ────────────────────────────────────

    final ids = <String>{};

    // 1. property_staff (new system)
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

    // 2. hotel_users (legacy)
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

    // 3. Org owner/admin fallback — only owners and admins see all org properties.
    //    Regular staff are excluded so they only see assigned properties (paths 1 & 2).
    if (ids.isEmpty) {
      try {
        final memberRows = await _db
            .from('organization_members')
            .select('org_id, role')
            .eq('user_id', userId)
            .limit(1);
        if (memberRows.isNotEmpty) {
          final role = memberRows.first['role'] as String? ?? '';
          if (role == 'owner' || role == 'admin') {
            final orgId = memberRows.first['org_id'] as String?;
            if (orgId != null) {
              final hotelRows = await _db
                  .from('hotels')
                  .select('id')
                  .eq('org_id', orgId);
              for (final r in hotelRows) {
                final id = r['id'] as String?;
                if (id != null) ids.add(id);
              }
            }
          }
        }
      } catch (_) {}
    }

    if (ids.isEmpty) return [];

    // 4. Fetch hotel details (with is_deleted fallback)
    List<dynamic> hotels;
    try {
      hotels = await _db
          .from('hotels')
          .select()
          .inFilter('id', ids.toList())
          .eq('is_deleted', false);
    } catch (_) {
      hotels = await _db
          .from('hotels')
          .select()
          .inFilter('id', ids.toList());
    }

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
    List<String> bookingChannels = const ['direct'],
  }) async {
    final slug = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';

    // Use SECURITY DEFINER RPC to bypass hotels RLS (no INSERT policy exists).
    final rows = await _db.rpc('create_property', params: {
      'p_org_id':           orgId,
      'p_name':             name,
      'p_slug':             slug,
      'p_type':             type,
      'p_address':          address,
      'p_city':             city,
      'p_country':          country,
      'p_phone':            phone,
      'p_email':            email,
      'p_timezone':         timezone,
      'p_currency':         currency,
      'p_logo_url':         logoUrl,
      'p_booking_channels': bookingChannels,
    });

    final row = (rows as List).first as Map<String, dynamic>;
    final property = OrgProperty.fromRow(row);

    // Update currency symbol in hotel_settings (RPC seeds it without symbol)
    await _db.from('hotel_settings').update({
      'currency_symbol': _currencySymbol(currency),
    }).eq('hotel_id', property.id);

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
        .eq('org_id', orgId)
        .eq('is_deleted', false);

    return rows.map((r) => OrgMember.fromRow(r)).toList();
  }

  Future<void> setMemberBillingPermission(String memberId, bool canManage) async {
    await _db
        .from('organization_members')
        .update({'can_manage_billing': canManage})
        .eq('id', memberId);
  }

  Future<void> setMemberBillingPermissionByUserId(
      String orgId, String userId, bool canManage) async {
    await _db
        .from('organization_members')
        .update({'can_manage_billing': canManage})
        .eq('org_id', orgId)
        .eq('user_id', userId);
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
      // Don't reveal whether the email is registered — return silently so the
      // caller's success message is shown regardless (prevents email enumeration).
      return;
    }

    await _db.from('organization_members').insert({
      'org_id':  orgId,
      'user_id': userRows.first['id'] as String,
      'role':    role,
    });
  }

  // ── Permanent deletion ───────────────────────────────────────────────────────

  Future<void> deleteOrganization(String orgId) async {
    await _db.rpc('delete_organization_cascade', params: {'p_org_id': orgId});
  }

  // ── Plan limits ──────────────────────────────────────────────────────────────

  // Maps plan field names to org custom_* column names
  static const _customLimitCol = {
    'max_properties': 'custom_max_properties',
    'max_users':      'custom_max_users',
    'max_rooms':      'custom_max_rooms',
    'max_tables':     'custom_max_tables',
  };

  /// Fetches the effective limit for [planField].
  /// Per-org custom overrides (custom_max_*) take precedence over the plan table.
  Future<int> _getPlanLimit(String orgId, String planField) async {
    try {
      final customCol = _customLimitCol[planField]!;
      final orgRow = await _db
          .from('organizations')
          .select('plan, $customCol')
          .eq('id', orgId)
          .single();

      // Custom override wins if set
      final custom = orgRow[customCol] as int?;
      if (custom != null) return custom;

      final slug = orgRow['plan'] as String? ?? 'free';
      final planRows = await _db
          .from('plans')
          .select(planField)
          .eq('slug', slug)
          .limit(1);
      if (planRows.isEmpty) return 1;
      return planRows.first[planField] as int;
    } catch (_) {
      return 1;
    }
  }

  // ── Custom plan provisioning ─────────────────────────────────────────────────

  /// Finds the organization that owns [email], upgrades their plan to 'enterprise'
  /// and sets per-org custom limits. Throws if no matching user/org is found.
  Future<void> provisionCustomAccess({
    required String email,
    required int maxProperties,
    required int maxUsers,
    required int maxRooms,
    required int maxTables,
    double? priceMonthly,
    double? priceAnnually,
    String? billingCycle, // 'monthly' | 'annually'
  }) async {
    // 1. Find user by email
    final profileRows = await _db
        .from('profiles')
        .select('id')
        .eq('email', email.trim().toLowerCase())
        .limit(1);
    if (profileRows.isEmpty) {
      throw Exception('No account found for "$email". '
          'Ask the customer to sign up first.');
    }
    final userId = profileRows.first['id'] as String;

    // 2. Find their organization
    final memberRows = await _db
        .from('organization_members')
        .select('org_id')
        .eq('user_id', userId)
        .limit(1);
    if (memberRows.isEmpty) {
      throw Exception('User "$email" has no organization. '
          'Ask them to complete onboarding first.');
    }
    final orgId = memberRows.first['org_id'] as String;

    // 3. Apply custom limits + upgrade plan
    await _db.from('organizations').update({
      'plan':                  'enterprise',
      'custom_max_properties': maxProperties,
      'custom_max_users':      maxUsers,
      'custom_max_rooms':      maxRooms,
      'custom_max_tables':     maxTables,
      if (priceMonthly  != null) 'custom_price_monthly':  priceMonthly,
      if (priceAnnually != null) 'custom_price_annually': priceAnnually,
      if (billingCycle  != null) 'billing_cycle':         billingCycle,
    }).eq('id', orgId);
  }

  /// Same as [provisionCustomAccess] but accepts a known [userId] directly.
  /// Used by [AuthNotifier.refreshAfterOnboarding] to auto-apply a pending
  /// enterprise provision that was set up before the user signed up.
  Future<void> provisionCustomAccessByUserId({
    required String userId,
    required int maxProperties,
    required int maxUsers,
    required int maxRooms,
    required int maxTables,
    double? priceMonthly,
    double? priceAnnually,
    String? billingCycle,
  }) async {
    final memberRows = await _db
        .from('organization_members')
        .select('org_id')
        .eq('user_id', userId)
        .limit(1);
    if (memberRows.isEmpty) return; // Org not created yet — silently skip

    final orgId = memberRows.first['org_id'] as String;

    await _db.from('organizations').update({
      'plan':                  'enterprise',
      'custom_max_properties': maxProperties,
      'custom_max_users':      maxUsers,
      'custom_max_rooms':      maxRooms,
      'custom_max_tables':     maxTables,
      if (priceMonthly  != null) 'custom_price_monthly':  priceMonthly,
      if (priceAnnually != null) 'custom_price_annually': priceAnnually,
      if (billingCycle  != null) 'billing_cycle':         billingCycle,
    }).eq('id', orgId);
  }

  Future<bool> canAddProperty(String orgId) async {
    final limit = await _getPlanLimit(orgId, 'max_properties');
    if (limit == -1) return true;
    final count = await _db.from('hotels').select('id').eq('org_id', orgId).count();
    return count.count < limit;
  }

  Future<bool> canAddStaff(String orgId) async {
    final limit = await _getPlanLimit(orgId, 'max_users');
    if (limit == -1) return true;
    final count = await _db.from('organization_members').select('id').eq('org_id', orgId).count();
    return count.count < limit;
  }

  Future<bool> canAddRoom(String orgId, String propertyId) async {
    final limit = await _getPlanLimit(orgId, 'max_rooms');
    if (limit == -1) return true;
    final count = await _db.from('rooms').select('id').eq('hotel_id', propertyId).count();
    return count.count < limit;
  }

  Future<bool> canAddTable(String orgId, String propertyId) async {
    final limit = await _getPlanLimit(orgId, 'max_tables');
    if (limit == -1) return true;
    final count = await _db.from('restaurant_tables').select('id').eq('hotel_id', propertyId).count();
    return count.count < limit;
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

  /// Soft-deletes a property (sets is_deleted=true). Data is preserved in DB.
  Future<void> deleteProperty(String propertyId) async {
    await _db.rpc('soft_delete_property', params: {'p_property_id': propertyId});
  }

  // ── Profile ───────────────────────────────────────────────────────────────────

  /// Returns the current user's profile from the profiles table.
  Future<Map<String, dynamic>?> getMyProfile() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _db
        .from('profiles')
        .select('id, full_name, job_title, phone, avatar_url, email')
        .eq('id', userId)
        .limit(1);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Updates the current user's profile fields.
  Future<void> updateProfile({
    required String fullName,
    String? jobTitle,
    String? phone,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db.from('profiles').update({
      'full_name':  fullName,
      'job_title':  jobTitle ?? '',
      'phone':      phone ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Soft-deletes the current user's account, org (if sole owner), and properties.
  /// The auth.users record is preserved — only application data is flagged deleted.
  Future<void> softDeleteMyAccount() async {
    await _db.rpc('soft_delete_profile');
  }

  // ── Property edit ────────────────────────────────────────────────────────────

  /// Updates core property fields in both `hotels` and `hotel_settings`.
  Future<void> updateProperty({
    required String propertyId,
    required String name,
    required String address,
    required String city,
    required String country,
    required String phone,
    required String email,
    required String timezone,
    required String currency,
    String primaryColor = '#D4A853',
    List<String>? bookingChannels,
  }) async {
    final hotelUpdate = <String, dynamic>{
      'name':          name,
      'address':       address,
      'city':          city,
      'country':       country,
      'phone':         phone,
      'email':         email,
      'timezone':      timezone,
      'currency':      currency,
      'primary_color': primaryColor,
    };
    if (bookingChannels != null) {
      hotelUpdate['booking_channels'] = bookingChannels;
    }
    await _db.from('hotels').update(hotelUpdate).eq('id', propertyId);

    await _db.from('hotel_settings').update({
      'display_name':    name,
      'address':         address,
      'phone':           phone,
      'email':           email,
      'currency_symbol': _currencySymbol(currency),
      'primary_color':   primaryColor,
    }).eq('hotel_id', propertyId);
  }

  // ── Property logo ─────────────────────────────────────────────────────────────

  /// Uploads [bytes] to the `property-logos` bucket and returns the public URL.
  /// The file is stored at `{propertyId}/logo.{ext}` and is upserted so
  /// re-uploading replaces the previous logo.
  Future<String> uploadPropertyLogo(
    String propertyId,
    Uint8List bytes,
    String fileName,
  ) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
    final path = '$propertyId/logo.$ext';
    await _db.storage.from('property-logos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
    return _db.storage.from('property-logos').getPublicUrl(path);
  }

  /// Saves [logoUrl] to both `hotels.logo_url` and `hotel_settings.logo_url`
  /// so invoice and in-app header both reflect the new logo immediately.
  Future<void> updatePropertyLogo(String propertyId, String logoUrl) async {
    await Future.wait([
      _db.from('hotels').update({'logo_url': logoUrl}).eq('id', propertyId),
      _db.from('hotel_settings').update({'logo_url': logoUrl}).eq('hotel_id', propertyId),
    ]);
  }
}
