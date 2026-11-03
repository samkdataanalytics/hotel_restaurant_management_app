import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ───────────────────────────────────────────────────────────────────
// Everything here comes from the superadmin_* functions in
// supabase/migrations/20261023000002_superadmin_user_tracking.sql. Parsing is
// tolerant: a missing or oddly typed field becomes a sensible empty value, so one
// strange row cannot blank the whole screen.

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
String _s(Object? v) => v is String ? v : '';
int _i(Object? v) => v is num ? v.toInt() : 0;
bool _b(Object? v) => v is bool && v;
List<Map<String, dynamic>> _maps(Object? v) =>
    v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

class UsersOverview {
  const UsersOverview({
    this.total = 0,
    this.new7d = 0,
    this.new30d = 0,
    this.active7d = 0,
    this.active30d = 0,
    this.unconfirmed = 0,
    this.neverSignedIn = 0,
    this.superadmins = 0,
    this.deleted = 0,
    this.actions24h = 0,
  });

  factory UsersOverview.fromJson(Map<String, dynamic> j) => UsersOverview(
        total: _i(j['total']),
        new7d: _i(j['new_7d']),
        new30d: _i(j['new_30d']),
        active7d: _i(j['active_7d']),
        active30d: _i(j['active_30d']),
        unconfirmed: _i(j['unconfirmed']),
        neverSignedIn: _i(j['never_signed_in']),
        superadmins: _i(j['superadmins']),
        deleted: _i(j['deleted']),
        actions24h: _i(j['actions_24h']),
      );

  final int total;
  final int new7d;
  final int new30d;
  final int active7d;
  final int active30d;
  final int unconfirmed;
  final int neverSignedIn;
  final int superadmins;
  final int deleted;
  final int actions24h;
}

class UserOrgRef {
  const UserOrgRef({required this.orgId, required this.name, required this.role, this.plan = '', this.status = ''});

  factory UserOrgRef.fromJson(Map<String, dynamic> j) => UserOrgRef(
        orgId: _s(j['org_id']),
        name: _s(j['name']),
        role: _s(j['role']),
        plan: _s(j['plan']),
        status: _s(j['status']),
      );

  final String orgId;
  final String name;
  final String role;
  final String plan;
  final String status;
}

class UserSummary {
  const UserSummary({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.jobTitle,
    required this.createdAt,
    required this.lastSignInAt,
    required this.emailConfirmed,
    required this.isSuperadmin,
    required this.isDeleted,
    required this.banned,
    required this.orgs,
    required this.activity30d,
    required this.lastActivityAt,
  });

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        userId: _s(j['user_id']),
        email: _s(j['email']),
        fullName: _s(j['full_name']),
        username: _s(j['username']),
        phone: _s(j['phone']),
        jobTitle: _s(j['job_title']),
        createdAt: _time(j['created_at']),
        lastSignInAt: _time(j['last_sign_in_at']),
        emailConfirmed: _b(j['email_confirmed']),
        isSuperadmin: _b(j['is_superadmin']),
        isDeleted: _b(j['is_deleted']),
        banned: _b(j['banned']),
        orgs: _maps(j['orgs']).map(UserOrgRef.fromJson).toList(),
        activity30d: _i(j['activity_30d']),
        lastActivityAt: _time(j['last_activity_at']),
      );

  final String userId;
  final String email;
  final String fullName;
  final String username;
  final String phone;
  final String jobTitle;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final bool emailConfirmed;
  final bool isSuperadmin;
  final bool isDeleted;
  final bool banned;
  final List<UserOrgRef> orgs;
  final int activity30d;
  final DateTime? lastActivityAt;

  /// Staff sign in by username, and their address is a synthetic
  /// `username@staff.internal`; showing that would only confuse.
  bool get hasRealEmail => email.isNotEmpty && !email.endsWith('@staff.internal');

  String get displayName =>
      fullName.isNotEmpty ? fullName : (username.isNotEmpty ? username : (hasRealEmail ? email.split('@').first : 'Unnamed user'));

  String get initials {
    if (fullName.isEmpty && username.isEmpty && !hasRealEmail) return '?';
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class UserPage {
  const UserPage({required this.users, required this.total});

  final List<UserSummary> users;

  /// Matches across all pages, not just this one.
  final int total;
}

class UserSession {
  const UserSession({this.started, this.refreshed, this.userAgent = '', this.ip = ''});

  factory UserSession.fromJson(Map<String, dynamic> j) => UserSession(
        started: _time(j['started']),
        refreshed: _time(j['refreshed']),
        userAgent: _s(j['user_agent']),
        ip: _s(j['ip']),
      );

  final DateTime? started;
  final DateTime? refreshed;
  final String userAgent;
  final String ip;

  /// "Chrome on macOS" from a raw user-agent string, good enough to recognise a
  /// device, not a fingerprint.
  String get device {
    final ua = userAgent;
    if (ua.isEmpty) return 'Unknown device';
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Firefox/')
            ? 'Firefox'
            : ua.contains('Chrome/')
                ? 'Chrome'
                : ua.contains('Safari/')
                    ? 'Safari'
                    : 'Browser';
    final os = ua.contains('iPhone') || ua.contains('iPad')
        ? 'iOS'
        : ua.contains('Android')
            ? 'Android'
            : ua.contains('Mac OS')
                ? 'macOS'
                : ua.contains('Windows')
                    ? 'Windows'
                    : ua.contains('Linux')
                        ? 'Linux'
                        : '';
    return os.isEmpty ? browser : '$browser on $os';
  }
}

class UserPayment {
  const UserPayment({required this.id, required this.plan, required this.cycle, required this.amount, required this.currency, required this.status, this.createdAt});

  factory UserPayment.fromJson(Map<String, dynamic> j) => UserPayment(
        id: _s(j['id']),
        plan: _s(j['plan']),
        cycle: _s(j['cycle']),
        amount: j['amount'] is num ? (j['amount'] as num).toDouble() : 0,
        currency: _s(j['currency']),
        status: _s(j['status']),
        createdAt: _time(j['created_at']),
      );

  final String id;
  final String plan;
  final String cycle;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
}

class UserProperty {
  const UserProperty({required this.propertyId, required this.name, required this.role});

  factory UserProperty.fromJson(Map<String, dynamic> j) =>
      UserProperty(propertyId: _s(j['property_id']), name: _s(j['name']), role: _s(j['role']));

  final String propertyId;
  final String name;
  final String role;
}

class ActionCount {
  const ActionCount(this.action, this.count);
  final String action;
  final int count;
}

class UserDetail {
  const UserDetail({
    required this.summary,
    required this.avatarUrl,
    required this.emailConfirmedAt,
    required this.bannedUntil,
    required this.providers,
    required this.sessionsOpen,
    required this.properties,
    required this.sessions,
    required this.payments,
    required this.invitesSent,
    required this.activityCounts,
    required this.activityTotal,
    required this.firstActivityAt,
    required this.lastActivityAt,
    required this.joinedOrgs,
  });

  factory UserDetail.fromJson(Map<String, dynamic> j) {
    final orgs = _maps(j['orgs']);
    return UserDetail(
      summary: UserSummary.fromJson({
        'user_id': j['user_id'],
        'email': j['email'],
        'full_name': j['full_name'],
        'username': j['username'],
        'phone': j['phone'],
        'job_title': j['job_title'],
        'created_at': j['created_at'],
        'last_sign_in_at': j['last_sign_in_at'],
        'email_confirmed': j['email_confirmed_at'] != null,
        'is_superadmin': j['is_superadmin'],
        'is_deleted': j['is_deleted'],
        'banned': _time(j['banned_until'])?.isAfter(DateTime.now()) ?? false,
        'orgs': orgs,
        'activity_30d': _maps(j['activity_counts']).fold<int>(0, (n, e) => n + (_s(e['action']).startsWith('auth.') ? 0 : _i(e['n']))),
        'last_activity_at': j['last_activity_at'],
      }),
      avatarUrl: _s(j['avatar_url']),
      emailConfirmedAt: _time(j['email_confirmed_at']),
      bannedUntil: _time(j['banned_until']),
      providers: j['providers'] is List ? [for (final p in j['providers'] as List) if (p is String) p] : const [],
      sessionsOpen: _i(j['sessions_open']),
      properties: _maps(j['properties']).map(UserProperty.fromJson).toList(),
      sessions: _maps(j['sessions']).map(UserSession.fromJson).toList(),
      payments: _maps(j['payments']).map(UserPayment.fromJson).toList(),
      invitesSent: _i(j['invites_sent']),
      activityCounts: _maps(j['activity_counts']).map((e) => ActionCount(_s(e['action']), _i(e['n']))).toList(),
      activityTotal: _i(j['activity_total']),
      firstActivityAt: _time(j['first_activity_at']),
      lastActivityAt: _time(j['last_activity_at']),
      joinedOrgs: {
        for (final o in orgs) _s(o['org_id']): _time(o['joined']),
      },
    );
  }

  final UserSummary summary;
  final String avatarUrl;
  final DateTime? emailConfirmedAt;
  final DateTime? bannedUntil;
  final List<String> providers;
  final int sessionsOpen;
  final List<UserProperty> properties;
  final List<UserSession> sessions;
  final List<UserPayment> payments;
  final int invitesSent;
  final List<ActionCount> activityCounts;
  final int activityTotal;
  final DateTime? firstActivityAt;
  final DateTime? lastActivityAt;
  final Map<String, DateTime?> joinedOrgs;
}

/// One line of the activity log.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.orgId,
    required this.orgName,
    required this.propertyId,
    required this.propertyName,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.detail,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: _i(j['id']),
        createdAt: _time(j['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        userId: _s(j['user_id']),
        userEmail: _s(j['user_email']),
        userName: _s(j['user_name']),
        orgId: _s(j['org_id']),
        orgName: _s(j['org_name']),
        propertyId: _s(j['property_id']),
        propertyName: _s(j['property_name']),
        action: _s(j['action']),
        entity: _s(j['entity']),
        entityId: _s(j['entity_id']),
        detail: j['detail'] is Map ? Map<String, dynamic>.from(j['detail'] as Map) : const {},
      );

  final int id;
  final DateTime createdAt;
  final String userId;
  final String userEmail;
  final String userName;
  final String orgId;
  final String orgName;
  final String propertyId;
  final String propertyName;
  final String action;
  final String entity;
  final String entityId;
  final Map<String, dynamic> detail;

  /// Who did it, for display. A change made without a session (a payment webhook,
  /// a scheduled job) has no actor.
  String get actor {
    if (userName.isNotEmpty) return userName;
    if (userEmail.isNotEmpty && !userEmail.endsWith('@staff.internal')) return userEmail;
    if (userEmail.endsWith('@staff.internal')) return userEmail.split('@').first;
    return userId.isEmpty ? 'System' : 'Unknown user';
  }

  bool get backfilled => detail['backfilled'] == true;
}

/// Plain-language names for the logged actions, and the groups the filters use.
class ActivityLabels {
  ActivityLabels._();

  /// Group → (label, action prefix passed to the server).
  static const groups = <(String label, String prefix)>[
    ('Everything', ''),
    ('Sign-ins & sign-ups', 'auth.'),
    ('Bookings', 'booking.'),
    ('Check-ins', 'check_in.'),
    ('Restaurant', 'order.'),
    ('Expenses', 'expense.'),
    ('Rooms & menu', 'room.'),
    ('Team', 'org_member.'),
    ('Billing', 'payment.'),
    ('Company changes', 'org.'),
    ('Profile', 'profile.'),
  ];

  static const _known = <String, String>{
    'auth.sign_up': 'Signed up',
    'auth.sign_in': 'Signed in',
    'booking.created': 'Created a booking',
    'booking.confirmed': 'Confirmed a booking',
    'booking.cancelled': 'Cancelled a booking',
    'booking.checked_in': 'Checked a guest in',
    'booking.checked_out': 'Checked a guest out',
    'booking.deleted': 'Deleted a booking',
    'check_in.created': 'Recorded a check-in',
    'order.created': 'Took a restaurant order',
    'order.deleted': 'Deleted a restaurant order',
    'order.served': 'Marked an order served',
    'order.paid': 'Took payment for an order',
    'order.cancelled': 'Cancelled an order',
    'expense.created': 'Recorded an expense',
    'expense.updated': 'Updated an expense',
    'expense.deleted': 'Deleted an expense',
    'room.created': 'Added a room',
    'room.deleted': 'Deleted a room',
    'menu_item.created': 'Added a menu item',
    'menu_item.deleted': 'Deleted a menu item',
    'table.created': 'Added a table',
    'table.deleted': 'Deleted a table',
    'org_member.created': 'Added a team member',
    'org_member.deleted': 'Removed a team member',
    'org_member.updated': 'Changed a team member',
    'property_staff.created': 'Assigned staff to a property',
    'property_staff.deleted': 'Removed staff from a property',
    'staff_invite.created': 'Invited a staff member',
    'shift.created': 'Scheduled a shift',
    'time_record.created': 'Clocked in',
    'time_record.updated': 'Clocked out',
    'payment.created': 'Started a payment',
    'payment.success': 'Payment succeeded',
    'payment.failed': 'Payment failed',
    'org.created': 'Created a company',
    'org.updated': 'Company details changed',
    'profile.updated': 'Updated their profile',
  };

  /// "Created a booking". Unknown actions read as "booking · paid" rather than
  /// the raw key, so a new trigger never shows a code to the admin.
  static String label(String action) {
    final k = _known[action];
    if (k != null) return k;
    final dot = action.indexOf('.');
    if (dot < 0) return action;
    final entity = action.substring(0, dot).replaceAll('_', ' ');
    final what = action.substring(dot + 1).replaceAll('_', ' ');
    return '${entity[0].toUpperCase()}${entity.substring(1)} · $what';
  }

  /// A short extra line from the entry's detail: reference, status change, amount.
  static String summary(ActivityEntry e) {
    final d = e.detail;
    final parts = <String>[];
    for (final k in const ['booking_ref', 'order_number', 'room_number', 'description', 'category', 'type']) {
      final v = d[k];
      if (v is String && v.isNotEmpty) {
        parts.add(v);
        break;
      }
    }
    final changed = d['changed'];
    if (changed is Map) {
      for (final entry in changed.entries) {
        final v = entry.value;
        if (v is Map) {
          parts.add('${_pretty(entry.key as String)}: ${_show(v['from'])} → ${_show(v['to'])}');
        }
      }
    }
    final amount = d['total_amount'] ?? d['amount'];
    if (amount is num && amount != 0) parts.add(amount == amount.roundToDouble() ? amount.round().toString() : amount.toString());
    if (d['plan_slug'] is String) parts.add('plan ${d['plan_slug']}');
    if (e.action.startsWith('org_member.') && d['role'] is String) parts.add('as ${d['role']}');
    if (e.action == 'staff_invite.created' && d['invited_email_domain'] is String && (d['invited_email_domain'] as String).isNotEmpty) {
      parts.add('@${d['invited_email_domain']}');
    }
    if (e.backfilled) parts.add('from existing records');
    return parts.join(' · ');
  }

  static String _pretty(String k) => k.replaceAll('_', ' ');
  static String _show(Object? v) => v == null ? '—' : '$v';
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Superadmin-only reads of registered users and their activity.
///
/// Every call goes through a SECURITY DEFINER function that refuses anyone who is
/// not a superadmin, so this class holds no permission logic of its own.
class UserTrackingService {
  UserTrackingService([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<UsersOverview> overview() async {
    final r = await _db.rpc('superadmin_users_overview');
    return UsersOverview.fromJson(r is Map ? Map<String, dynamic>.from(r) : const {});
  }

  Future<UserPage> listUsers({String search = '', String filter = 'all', int limit = 25, int offset = 0}) async {
    final rows = await _db.rpc('superadmin_list_users', params: {
      'p_search': search,
      'p_filter': filter,
      'p_limit': limit,
      'p_offset': offset,
    });
    final list = rows is List ? [for (final e in rows) if (e is Map) Map<String, dynamic>.from(e)] : <Map<String, dynamic>>[];
    return UserPage(
      users: list.map(UserSummary.fromJson).toList(),
      total: list.isEmpty ? 0 : _i(list.first['total_count']),
    );
  }

  Future<UserDetail> userDetail(String userId) async {
    final r = await _db.rpc('superadmin_user_detail', params: {'p_user_id': userId});
    return UserDetail.fromJson(r is Map ? Map<String, dynamic>.from(r) : const {});
  }

  /// A page of the log, newest first. Pass the last entry's time as [before] for the
  /// next page.
  Future<List<ActivityEntry>> activity({
    String? userId,
    String? orgId,
    String? propertyId,
    String actionPrefix = '',
    int limit = 50,
    DateTime? before,
  }) async {
    final params = {
      'p_user_id': userId,
      'p_org_id': orgId,
      'p_action_prefix': actionPrefix.isEmpty ? null : actionPrefix,
      'p_limit': limit,
      'p_before': before?.toUtc().toIso8601String(),
    };
    // Filtering by property needs the newer function (migration ...0004); every
    // other view keeps using the original, so users and companies still work on a
    // database that has only ...0002.
    final rows = propertyId == null
        ? await _db.rpc('superadmin_user_activity', params: params)
        : await _db.rpc('superadmin_activity', params: {...params, 'p_property_id': propertyId});
    return rows is List ? [for (final e in rows) if (e is Map) ActivityEntry.fromJson(Map<String, dynamic>.from(e))] : const [];
  }
}
