import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/providers/service_providers.dart';
import 'package:hotel_checkin/services/user_tracking_service.dart';
import 'package:hotel_checkin/web/superadmin/users/activity_list.dart';
import 'package:hotel_checkin/web/superadmin/users/superadmin_users_screen.dart';
import 'package:hotel_checkin/web/superadmin/users/users_format.dart';

import '../cms/support/brand_fonts.dart';

Map<String, dynamic> _userJson({
  String id = 'u1',
  String email = 'ada@example.com',
  String name = 'Ada Lovelace',
  String? lastSignIn,
  bool confirmed = true,
  bool superadmin = false,
  List<Map<String, dynamic>> orgs = const [],
  int activity = 0,
  int total = 1,
}) =>
    {
      'user_id': id,
      'email': email,
      'full_name': name,
      'username': null,
      'phone': '',
      'job_title': 'Owner',
      'created_at': DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String(),
      'last_sign_in_at': lastSignIn,
      'email_confirmed': confirmed,
      'is_superadmin': superadmin,
      'is_deleted': false,
      'banned': false,
      'orgs': orgs,
      'activity_30d': activity,
      'last_activity_at': null,
      'total_count': total,
    };

Map<String, dynamic> _entryJson(int id, String action, {Map<String, dynamic> detail = const {}, String name = 'Ada Lovelace'}) => {
      'id': id,
      'created_at': DateTime.now().subtract(Duration(minutes: id)).toUtc().toIso8601String(),
      'user_id': 'u1',
      'user_email': 'ada@example.com',
      'user_name': name,
      'org_id': 'o1',
      'org_name': 'Acme',
      'property_id': 'p1',
      'property_name': 'Acme Hotel',
      'action': action,
      'entity': action.split('.').first,
      'entity_id': 'e$id',
      'detail': detail,
    };

class _FakeService extends UserTrackingService {
  _FakeService({this.users = const [], this.entries = const [], this.fail});

  final List<UserSummary> users;
  final List<ActivityEntry> entries;
  final Object? fail;
  final calls = <String>[];

  @override
  Future<UsersOverview> overview() async {
    calls.add('overview');
    if (fail != null) throw fail!;
    return const UsersOverview(total: 8, new7d: 2, active7d: 5, neverSignedIn: 1, unconfirmed: 1, actions24h: 17);
  }

  @override
  Future<UserPage> listUsers({String search = '', String filter = 'all', int limit = 25, int offset = 0}) async {
    calls.add('list:$search:$filter:$offset');
    if (fail != null) throw fail!;
    final hit = users.where((u) => search.isEmpty || u.displayName.toLowerCase().contains(search.toLowerCase()) || u.email.contains(search)).toList();
    return UserPage(users: hit.skip(offset).take(limit).toList(), total: hit.length);
  }

  @override
  Future<UserDetail> userDetail(String userId) async {
    calls.add('detail:$userId');
    return UserDetail.fromJson({
      ..._userJson(id: userId, lastSignIn: DateTime.now().toUtc().toIso8601String(), orgs: [
        {'org_id': 'o1', 'name': 'Acme', 'role': 'owner', 'plan': 'growth', 'status': 'active', 'joined': DateTime.now().toUtc().toIso8601String()}
      ]),
      'email_confirmed_at': DateTime.now().toUtc().toIso8601String(),
      'providers': ['email'],
      'sessions_open': 1,
      'properties': [
        {'property_id': 'p1', 'name': 'Acme Hotel', 'role': 'manager', 'org_id': 'o1'}
      ],
      'sessions': [
        {'started': DateTime.now().toUtc().toIso8601String(), 'refreshed': null, 'user_agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120 Safari/537', 'ip': '203.0.113.9'}
      ],
      'payments': [
        {'id': 'PH-1', 'plan': 'growth', 'cycle': 'monthly', 'amount': 7999, 'currency': 'LKR', 'status': 'success', 'created_at': DateTime.now().toUtc().toIso8601String()}
      ],
      'invites_sent': 3,
      'activity_counts': [
        {'action': 'booking.created', 'n': 12},
        {'action': 'auth.sign_in', 'n': 9},
      ],
      'activity_total': 40,
      'first_activity_at': DateTime.now().subtract(const Duration(days: 40)).toUtc().toIso8601String(),
      'last_activity_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<ActivityEntry>> activity({String? userId, String? orgId, String? propertyId, String actionPrefix = '', int limit = 50, DateTime? before}) async {
    calls.add('activity:${userId ?? '-'}:${orgId ?? '-'}:$actionPrefix:${before != null}${propertyId == null ? '' : ':p=$propertyId'}');
    if (fail != null) throw fail!;
    final list = entries.where((e) => actionPrefix.isEmpty || e.action.startsWith(actionPrefix)).where((e) => before == null || e.createdAt.isBefore(before)).toList();
    return list.take(limit).toList();
  }
}

UserSummary _u(Map<String, dynamic> j) => UserSummary.fromJson(j);

Future<_FakeService> _pump(WidgetTester t, Widget child, {_FakeService? svc, double width = 1400}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = svc ?? _FakeService();
  await t.pumpWidget(ProviderScope(
    overrides: [userTrackingServiceProvider.overrideWithValue(s)],
    child: MaterialApp(theme: ThemeData(fontFamily: 'Inter'), home: Scaffold(body: child)),
  ));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return s;
}

void main() {
  setUpAll(loadBrandFonts);

  group('models', () {
    test('a user row parses, with its companies', () {
      final u = _u(_userJson(orgs: [
        {'org_id': 'o1', 'name': 'Acme', 'role': 'owner', 'plan': 'growth', 'status': 'active'}
      ], activity: 12));
      expect(u.displayName, 'Ada Lovelace');
      expect(u.initials, 'AL');
      expect(u.orgs.single.role, 'owner');
      expect(u.activity30d, 12);
      expect(u.hasRealEmail, isTrue);
    });

    test('junk and missing fields become empty values, never an exception', () {
      final u = UserSummary.fromJson({'user_id': 5, 'orgs': 'x', 'created_at': 'not a date', 'activity_30d': 'many'});
      expect(u.userId, '');
      expect(u.orgs, isEmpty);
      expect(u.createdAt, isNull);
      expect(u.activity30d, 0);
      expect(u.displayName, 'Unnamed user');
      expect(u.initials, '?');
      expect(UsersOverview.fromJson(const {}).total, 0);
      expect(ActivityEntry.fromJson(const {}).actor, 'System');
    });

    test('a staff username account does not show its synthetic address', () {
      final u = _u(_userJson(email: 'manager_01@staff.internal', name: ''));
      expect(u.hasRealEmail, isFalse);
      final e = ActivityEntry.fromJson({..._entryJson(1, 'booking.created', name: ''), 'user_email': 'manager_01@staff.internal'});
      expect(e.actor, 'manager_01');
    });

    test('detail combines the profile, sessions, payments and action counts', () async {
      final d = await _FakeService().userDetail('u9');
      expect(d.summary.userId, 'u9');
      expect(d.properties.single.name, 'Acme Hotel');
      expect(d.payments.single.amount, 7999);
      expect(d.sessions.single.device, 'Chrome on macOS');
      expect(d.activityCounts.first.count, 12);
      expect(d.summary.activity30d, 12, reason: 'sign-ins are not counted as work done');
      expect(d.activityTotal, 40);
    });

    test('device names from user agents', () {
      String dev(String ua) => UserSession(userAgent: ua).device;
      expect(dev('Mozilla/5.0 (iPhone; CPU iPhone OS 17) Safari/604'), 'Safari on iOS');
      expect(dev('Mozilla/5.0 (Linux; Android 14) Chrome/120 Mobile Safari/537'), 'Chrome on Android');
      expect(dev('Mozilla/5.0 (Windows NT 10.0) Edg/120 Chrome/120'), 'Edge on Windows');
      expect(dev(''), 'Unknown device');
    });
  });

  group('activity wording', () {
    test('known actions read as sentences, unknown ones are made readable', () {
      expect(ActivityLabels.label('booking.created'), 'Created a booking');
      expect(ActivityLabels.label('auth.sign_in'), 'Signed in');
      expect(ActivityLabels.label('widget.paint_job'), 'Widget · paint job');
      expect(ActivityLabels.label('nodots'), 'nodots');
    });

    test('summaries show reference, transition and amount', () {
      final e = ActivityEntry.fromJson(_entryJson(1, 'booking.confirmed', detail: {
        'booking_ref': 'BK-0042',
        'total_amount': 120,
        'changed': {
          'status': {'from': 'pending', 'to': 'confirmed'}
        },
      }));
      expect(ActivityLabels.summary(e), 'BK-0042 · status: pending → confirmed · 120');
    });

    test('membership entries say which role', () {
      final e = ActivityEntry.fromJson(_entryJson(1, 'org_member.created', detail: {'role': 'manager'}));
      expect(ActivityLabels.summary(e), 'as manager');
    });

    test('backfilled entries say so', () {
      final e = ActivityEntry.fromJson(_entryJson(1, 'auth.sign_in', detail: {'backfilled': true}));
      expect(ActivityLabels.summary(e), 'from existing records');
    });

    test('the filter groups all exist and are unique', () {
      final prefixes = ActivityLabels.groups.map((g) => g.$2).toList();
      expect(prefixes.toSet().length, prefixes.length);
      expect(prefixes.first, '');
    });
  });

  group('formatting and export', () {
    final now = DateTime(2026, 10, 23, 12, 0);

    test('relative times', () {
      expect(relativeTime(null), 'never');
      expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(relativeTime(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
      expect(relativeTime(now.subtract(const Duration(days: 9)), now: now), '9 days ago');
      expect(relativeTime(DateTime(2026, 1, 5), now: now), '5 Jan 2026');
      expect(relativeTime(now.add(const Duration(minutes: 3)), now: now), 'just now', reason: 'clock skew');
    });

    test('CSV quotes, escapes and neutralises formulas', () {
      expect(csvCell('plain'), 'plain');
      expect(csvCell('a,b'), '"a,b"');
      expect(csvCell('say "hi"'), '"say ""hi"""');
      expect(csvCell('line\nbreak'), '"line\nbreak"');
      expect(csvCell('=HYPERLINK("http://evil")'), "\"'=HYPERLINK(\"\"http://evil\"\")\"");
      expect(csvCell('+1 555'), "'+1 555");
      expect(csvCell('-5'), "'-5");
      expect(csvCell('@sum'), "'@sum");
      expect(csvCell(null), '');
      expect(csvCell(7), '7');
    });

    test('the users export has a header, one row each, and hides synthetic emails', () {
      final csv = usersCsv([
        _u(_userJson(name: 'Ada, Countess', orgs: [
          {'org_id': 'o1', 'name': 'Acme', 'role': 'owner'}
        ])),
        _u(_userJson(id: 'u2', email: 'm@staff.internal', name: '=cmd')),
      ]);
      final lines = csv.trim().split('\r\n');
      expect(lines.length, 3);
      expect(lines[0], startsWith('Name,Email,Username'));
      expect(lines[1], contains('"Ada, Countess"'));
      expect(lines[1], contains('Acme (owner)'));
      expect(lines[2], contains("'=cmd"));
      expect(lines[2], isNot(contains('staff.internal')));
    });
  });

  group('Users screen', () {
    List<UserSummary> sample() => [
          _u(_userJson(id: 'u1', lastSignIn: DateTime.now().toUtc().toIso8601String(), activity: 14, orgs: [
            {'org_id': 'o1', 'name': 'Acme', 'role': 'owner'}
          ], total: 3)),
          _u(_userJson(id: 'u2', email: 'bob@example.com', name: 'Bob Stone', confirmed: false, total: 3)),
          _u(_userJson(id: 'u3', email: 'root@example.com', name: 'Root Admin', superadmin: true, lastSignIn: DateTime.now().toUtc().toIso8601String(), total: 3)),
        ];

    testWidgets('shows the headline numbers and every user with their status', (t) async {
      final s = await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample()));
      expect(find.text('Registered users'), findsOneWidget);
      expect(find.text('Actions in 24 h'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Bob Stone'), findsOneWidget);
      expect(find.text('Acme · owner'), findsOneWidget);
      expect(find.text('Superadmin'), findsOneWidget);
      expect(find.text('Email not confirmed'), findsWidgets);
      expect(find.text('Never signed in'), findsWidgets);
      expect(s.calls, contains('list::all:0'));
      expect(t.takeException(), isNull);
    });

    testWidgets('searching asks the server, after a short pause', (t) async {
      final s = await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample()));
      await t.enterText(find.byType(TextField), 'bob');
      await t.pump(const Duration(milliseconds: 100));
      expect(s.calls.where((c) => c.startsWith('list:bob')), isEmpty, reason: 'still waiting for typing to stop');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 100));
      expect(s.calls, contains('list:bob:all:0'));
      expect(find.text('Bob Stone'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
    });

    testWidgets('a filter chip refetches with that filter', (t) async {
      final s = await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample()));
      await t.tap(find.text('Superadmins'));
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.calls, contains('list::superadmin:0'));
    });

    testWidgets('clicking a user opens their details, with companies, payments and sessions', (t) async {
      final s = await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample()));
      await t.tap(find.text('Ada Lovelace'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.calls, contains('detail:u1'));
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Companies'), findsOneWidget);
      expect(find.text('Acme Hotel'), findsWidgets);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('LKR 7999'), findsOneWidget);
      expect(find.textContaining('Activity (40)'), findsOneWidget);

      await t.tap(find.textContaining('Sessions'));
      await t.pumpAndSettle();
      expect(find.text('Chrome on macOS'), findsOneWidget);
      expect(find.text('203.0.113.9'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the Activity feed tab lists what people did, newest first, with the actor', (t) async {
      final entries = [
        ActivityEntry.fromJson(_entryJson(1, 'booking.created', detail: {'booking_ref': 'BK-1'})),
        ActivityEntry.fromJson(_entryJson(2, 'auth.sign_in', name: 'Bob Stone')),
      ];
      final s = await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample(), entries: entries));
      await t.tap(find.text('Activity feed'));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Created a booking', findRichText: true), findsOneWidget);
      expect(find.text('BK-1'), findsOneWidget);
      expect(find.textContaining('Signed in', findRichText: true), findsOneWidget);
      expect(find.textContaining('Bob Stone', findRichText: true), findsOneWidget);
      expect(s.calls.where((c) => c.startsWith('activity:-:-::')), isNotEmpty);
    });

    testWidgets('a database without the tracking functions says what to do', (t) async {
      await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(fail: Exception('Could not find the function public.superadmin_list_users (PGRST202)')));
      expect(find.textContaining('not installed'), findsOneWidget);
      expect(find.textContaining('20261023000002_superadmin_user_tracking.sql'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a non-superadmin is told so, not shown a stack trace', (t) async {
      await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(fail: Exception('Only a superadmin (42501)')));
      expect(find.text('Only a superadmin can view users.'), findsOneWidget);
    });

    testWidgets('an empty search result is explained', (t) async {
      await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: const []));
      expect(find.textContaining('No users match'), findsOneWidget);
    });

    testWidgets('a narrow window stacks each row without overflowing', (t) async {
      await _pump(t, const SuperadminUsersScreen(), svc: _FakeService(users: sample()), width: 700);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('ActivityList', () {
    testWidgets('filtering by group sends the action prefix and loads older pages with a cursor', (t) async {
      final many = [for (var i = 1; i <= 45; i++) ActivityEntry.fromJson(_entryJson(i, i.isEven ? 'booking.created' : 'order.created'))];
      final s = await _pump(t, const SingleChildScrollView(child: ActivityList(orgId: 'o1')), svc: _FakeService(entries: many));
      expect(s.calls.first, 'activity:-:o1::false');
      expect(find.text('Load older'), findsOneWidget);

      await t.ensureVisible(find.text('Load older'));
      await t.tap(find.text('Load older'));
      await t.pump(const Duration(milliseconds: 200));
      expect(s.calls.last, 'activity:-:o1::true');

      await t.ensureVisible(find.text('Bookings'));
      await t.tap(find.text('Bookings'));
      await t.pump(const Duration(milliseconds: 200));
      expect(s.calls.last, 'activity:-:o1:booking.:false');
    });

    testWidgets('shows a hint when nothing has been recorded', (t) async {
      await _pump(t, const SingleChildScrollView(child: ActivityList(userId: 'u1', showActor: false)));
      expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
    });
  });
}
