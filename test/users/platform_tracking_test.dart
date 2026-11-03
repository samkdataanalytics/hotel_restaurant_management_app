import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/providers/service_providers.dart';
import 'package:hotel_checkin/services/platform_tracking_service.dart';
import 'package:hotel_checkin/services/user_tracking_service.dart';
import 'package:hotel_checkin/web/superadmin/companies_list_screen.dart';
import 'package:hotel_checkin/web/superadmin/tracking/company_insight_view.dart';
import 'package:hotel_checkin/web/superadmin/tracking/platform_overview_panel.dart';
import 'package:hotel_checkin/web/superadmin/tracking/superadmin_properties_screen.dart';
import 'package:hotel_checkin/web/superadmin/tracking/tracking_widgets.dart';
import 'package:hotel_checkin/web/superadmin/users/activity_list.dart';

import '../cms/support/brand_fonts.dart';

String _ago(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _company({
  String id = 'o1',
  String name = 'Seaview Group',
  String status = 'active',
  String plan = 'growth',
  int props = 2,
  int total = 3,
  String? trial,
}) =>
    {
      'org_id': id,
      'name': name,
      'slug': 'seaview',
      'plan': plan,
      'status': status,
      'country': 'LK',
      'phone': '+94 11 000',
      'email': 'hello@seaview.test',
      'created_at': _ago(const Duration(days: 90)),
      'trial_ends_at': trial,
      'billing_cycle': 'monthly',
      'subscription_paid_at': null,
      'logo_url': '',
      'custom_price_monthly': null,
      'custom_price_annually': null,
      'is_deleted': false,
      'owner_id': 'u1',
      'owner_name': 'Ada Lovelace',
      'owner_email': 'ada@example.com',
      'members': 4,
      'properties': props,
      'rooms': 20,
      'tables': 8,
      'bookings_30d': 11,
      'orders_30d': 37,
      'actions_30d': 120,
      'last_activity_at': _ago(const Duration(hours: 3)),
      'last_sign_in_at': _ago(const Duration(hours: 1)),
      'total_count': total,
    };

Map<String, dynamic> _property({String id = 'p1', String name = 'Seaview Hotel', String type = 'both', int total = 2}) => {
      'property_id': id,
      'org_id': 'o1',
      'org_name': 'Seaview Group',
      'org_plan': 'growth',
      'org_status': 'active',
      'name': name,
      'type': type,
      'city': 'Galle',
      'country': 'LK',
      'status': 'active',
      'currency': 'LKR',
      'is_deleted': false,
      'created_at': _ago(const Duration(days: 60)),
      'rooms': 12,
      'tables': 6,
      'staff': 5,
      'bookings_total': 80,
      'bookings_30d': 9,
      'orders_30d': 31,
      'paid_value_30d': 150000,
      'actions_30d': 64,
      'last_activity_at': _ago(const Duration(minutes: 20)),
      'total_count': total,
    };

Map<String, dynamic> _companyDetail() => {
      'org_id': 'o1',
      'name': 'Seaview Group',
      'plan': 'growth',
      'status': 'trialing',
      'country': 'LK',
      'phone': '+94 11 000',
      'email': 'hello@seaview.test',
      'created_at': _ago(const Duration(days: 90)),
      'created_by_name': 'Ada Lovelace',
      'created_by_email': 'ada@example.com',
      'trial_ends_at': DateTime.now().add(const Duration(days: 4, hours: 2)).toUtc().toIso8601String(),
      'billing_cycle': 'monthly',
      'limits': {
        'properties': {'max': 3, 'used': 2},
        'users': {'max': 5, 'used': 6},
        'rooms': {'max': null, 'used': 20},
        'tables': {'max': -1, 'used': 8},
      },
      'totals': {'bookings': 80, 'bookings_30d': 11, 'paid_bookings_value': 150000, 'orders': 300, 'orders_30d': 37, 'expenses_value': 4200, 'pending_invites': 2},
      'members': [
        {'user_id': 'u1', 'name': 'Ada Lovelace', 'email': 'ada@example.com', 'role': 'owner', 'last_sign_in_at': _ago(const Duration(hours: 1)), 'actions_30d': 70},
        {'user_id': 'u2', 'name': '', 'email': 'cook_01@staff.internal', 'username': 'cook_01', 'role': 'staff', 'last_sign_in_at': null, 'actions_30d': 0},
      ],
      'properties': [
        {'property_id': 'p1', 'name': 'Seaview Hotel', 'type': 'both', 'status': 'active', 'rooms': 12, 'tables': 6, 'bookings_30d': 9, 'orders_30d': 31, 'last_activity_at': _ago(const Duration(minutes: 20))},
      ],
      'payments': [
        {'id': 'PH-1', 'plan': 'growth', 'cycle': 'monthly', 'amount': 7999, 'currency': 'LKR', 'status': 'success', 'created_at': _ago(const Duration(days: 2)), 'payer': 'Ada Lovelace'},
      ],
      'activity_counts': [
        {'action': 'booking.created', 'n': 11},
        {'action': 'order.created', 'n': 37},
      ],
      'activity_total': 400,
      'first_activity_at': _ago(const Duration(days: 80)),
      'last_activity_at': _ago(const Duration(hours: 3)),
    };

Map<String, dynamic> _propertyDetail() => {
      'property_id': 'p1',
      'name': 'Seaview Hotel',
      'slug': 'seaview-hotel',
      'type': 'both',
      'address': '1 Beach Rd',
      'city': 'Galle',
      'country': 'LK',
      'phone': '+94 91 000',
      'email': 'front@seaview.test',
      'timezone': 'Asia/Colombo',
      'currency': 'LKR',
      'status': 'active',
      'booking_channels': ['direct', 'airbnb'],
      'is_deleted': false,
      'created_at': _ago(const Duration(days: 60)),
      'company': {'org_id': 'o1', 'name': 'Seaview Group', 'plan': 'growth', 'status': 'active'},
      'settings': {'tax_rate': 8, 'service_charge_rate': 10, 'currency_symbol': 'LKR'},
      'rooms_by_status': {'available': 9, 'occupied': 3},
      'tables_by_status': {'free': 6},
      'bookings_by_status': {'checkedOut': 70, 'pending': 10},
      'orders_by_status': {'served': 290},
      'totals': {'bookings': 80, 'bookings_30d': 9, 'paid_value': 900000, 'paid_value_30d': 150000, 'orders': 300, 'orders_30d': 31, 'expenses_30d': 5200, 'menu_items': 44},
      'expenses_by_category': [
        {'category': 'supplies', 'amount': 3200},
        {'category': 'utilities', 'amount': 2000},
      ],
      'staff': [
        {'user_id': 'u3', 'name': 'Bob Stone', 'email': 'bob@example.com', 'role': 'manager', 'last_sign_in_at': _ago(const Duration(days: 2)), 'actions_30d': 12},
      ],
      'company_access': [
        {'user_id': 'u1', 'name': 'Ada Lovelace', 'email': 'ada@example.com', 'role': 'owner', 'last_sign_in_at': _ago(const Duration(hours: 1))},
      ],
      'recent_bookings': [
        {'ref': 'BK-0042', 'status': 'pending', 'check_in': _ago(const Duration(days: -3)), 'check_out': _ago(const Duration(days: -5)), 'amount': 24000, 'paid': false, 'source': 'direct', 'created_at': _ago(const Duration(hours: 5))},
      ],
      'recent_orders': [
        {'number': 'ORD-77', 'status': 'served', 'type': 'dine_in', 'payment_status': 'paid', 'room': '', 'items': 3, 'created_at': _ago(const Duration(minutes: 40))},
      ],
      'activity_counts': [
        {'action': 'order.created', 'n': 31},
      ],
      'activity_total': 210,
      'first_activity_at': _ago(const Duration(days: 58)),
      'last_activity_at': _ago(const Duration(minutes: 20)),
    };

class _FakePlatform extends PlatformTrackingService {
  _FakePlatform({this.fail, this.companies = const [], this.properties = const []});

  final Object? fail;
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> properties;
  final calls = <String>[];

  void _maybeFail() {
    if (fail != null) throw fail!;
  }

  @override
  Future<PlatformOverview> overview() async {
    calls.add('overview');
    _maybeFail();
    return PlatformOverview.fromJson({
      'companies': {'total': 5, 'deleted': 1, 'new_30d': 2, 'by_status': {'active': 3, 'trialing': 1, 'trial_expired': 1}, 'by_plan': {'growth': 3, 'starter': 2}, 'dormant_30d': 2},
      'properties': {'total': 7, 'active': 6, 'new_30d': 1, 'by_type': {'hotel': 3, 'both': 4}},
      'users': {'total': 22, 'active_7d': 9},
      'inventory': {'rooms': 80, 'tables': 31},
      'bookings': {'total': 900, 'last_30d': 120, 'paid_value_30d': 1250000},
      'orders': {'total': 5000, 'last_30d': 800},
      'subscriptions': {'paid_count': 4, 'paid_amount': 40000, 'paid_30d': 16000, 'pending': 1},
      'activity': {
        'actions_24h': 55,
        'actions_7d': 400,
        'daily': [for (var i = 0; i < 14; i++) {'day': DateTime.now().subtract(Duration(days: 13 - i)).toIso8601String().substring(0, 10), 'signups': i % 3, 'sign_ins': i, 'actions': i * 5}],
      },
      'busiest_companies': [
        {'org_id': 'o1', 'name': 'Seaview Group', 'actions': 320}
      ],
      'trials_ending': [
        {'org_id': 'o2', 'name': 'Tin Stays', 'trial_ends_at': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String()}
      ],
    });
  }

  @override
  Future<CompanyPage> listCompanies({String search = '', String filter = 'all', int limit = 25, int offset = 0}) async {
    calls.add('companies:$search:$filter:$offset');
    _maybeFail();
    final hit = companies.where((c) => search.isEmpty || (c['name'] as String).toLowerCase().contains(search.toLowerCase())).toList();
    return CompanyPage(companies: hit.skip(offset).take(limit).map(CompanySummary.fromJson).toList(), total: hit.length);
  }

  @override
  Future<CompanyInsight> companyDetail(String orgId) async {
    calls.add('company:$orgId');
    _maybeFail();
    return CompanyInsight.fromJson(_companyDetail());
  }

  @override
  Future<PropertyPage> listProperties({String search = '', String filter = 'all', String? orgId, int limit = 25, int offset = 0}) async {
    calls.add('properties:$search:$filter:${orgId ?? '-'}:$offset');
    _maybeFail();
    final hit = properties.where((c) => search.isEmpty || (c['name'] as String).toLowerCase().contains(search.toLowerCase())).toList();
    return PropertyPage(properties: hit.skip(offset).take(limit).map(PropertySummary.fromJson).toList(), total: hit.length);
  }

  @override
  Future<PropertyInsight> propertyDetail(String propertyId) async {
    calls.add('property:$propertyId');
    _maybeFail();
    return PropertyInsight.fromJson(_propertyDetail());
  }
}

class _FakeUsers extends UserTrackingService {
  final calls = <String>[];

  @override
  Future<List<ActivityEntry>> activity({String? userId, String? orgId, String? propertyId, String actionPrefix = '', int limit = 50, DateTime? before}) async {
    calls.add('activity:${userId ?? '-'}:${orgId ?? '-'}:${propertyId ?? '-'}');
    return const [];
  }
}

Future<({_FakePlatform platform, _FakeUsers users})> _pump(WidgetTester t, Widget child, {_FakePlatform? platform, double width = 1400}) async {
  t.view.physicalSize = Size(width, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final p = platform ?? _FakePlatform();
  final u = _FakeUsers();
  await t.pumpWidget(ProviderScope(
    overrides: [platformTrackingServiceProvider.overrideWithValue(p), userTrackingServiceProvider.overrideWithValue(u)],
    child: MaterialApp(theme: ThemeData(fontFamily: 'Inter'), home: Scaffold(body: child)),
  ));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  return (platform: p, users: u);
}

void main() {
  setUpAll(loadBrandFonts);

  group('models', () {
    test('a company row parses and maps to the old model for the existing dialog', () {
      final c = CompanySummary.fromJson(_company(status: 'trial_expired', trial: _ago(const Duration(days: 2))));
      expect(c.name, 'Seaview Group');
      expect(c.ownerLabel, 'Ada Lovelace');
      expect(c.properties, 2);
      final org = c.toOrganization();
      expect(org.id, 'o1');
      expect(org.plan, 'growth');
      expect(org.propertyCount, 2);
      expect(org.memberCount, 4);
      expect(org.effectiveStatus, 'trial_expired', reason: 'the dialog derives it from the trial date');
    });

    test('junk and missing fields never throw', () {
      final c = CompanySummary.fromJson({'org_id': 5, 'members': 'x', 'created_at': 'nope'});
      expect(c.orgId, '');
      expect(c.members, 0);
      expect(c.createdAt, isNull);
      expect(c.toOrganization().name, '');
      expect(PlatformOverview.fromJson(const {}).companies, 0);
      expect(PropertyInsight.fromJson(const {}).name, '');
      expect(CompanyInsight.fromJson(const {}).limits['rooms']!.unlimited, isTrue);
    });

    test('limits: used over max is flagged; null and -1 mean unlimited', () {
      final c = CompanyInsight.fromJson(_companyDetail());
      expect(c.limits['properties']!.over, isFalse);
      expect(c.limits['properties']!.fraction, closeTo(2 / 3, 0.001));
      expect(c.limits['users']!.over, isTrue);
      expect(c.limits['users']!.fraction, 1);
      expect(c.limits['rooms']!.unlimited, isTrue);
      expect(c.limits['tables']!.unlimited, isTrue);
      expect(c.limits['tables']!.over, isFalse);
    });

    test('a company with a staff-only address does not show it as the owner', () {
      final c = CompanySummary.fromJson({..._company(), 'owner_name': '', 'owner_email': 'x@staff.internal'});
      expect(c.ownerLabel, '');
    });

    test('the overview keeps the 14-day series in order', () async {
      final o = await _FakePlatform().overview();
      expect(o.daily.length, 14);
      expect(o.daily.first.day.isBefore(o.daily.last.day), isTrue);
      expect(o.companiesByStatus['trial_expired'], 1);
      expect(o.busiest.single.value, 320);
      expect(o.trialsEnding.single.at, isNotNull);
    });

    test('property detail parses people, bookings and orders', () {
      final p = PropertyInsight.fromJson(_propertyDetail());
      expect(p.orgName, 'Seaview Group');
      expect(p.staff.single.role, 'manager');
      expect(p.recentBookings.single.ref, 'BK-0042');
      expect(p.recentOrders.single.items, 3);
      expect(p.expensesByCategory['supplies'], 3200);
      expect(p.roomsByStatus['available'], 9);
      expect(p.total('paid_value_30d'), 150000);
    });

    test('money formatting', () {
      expect(money(1234567), '1,234,567');
      expect(money(1250.5, 'LKR'), 'LKR 1,250.50');
      expect(money(0), '0');
    });
  });

  group('Companies list', () {
    testWidgets('shows owner, plan, status with trial days left, usage and activity', (t) async {
      final trial = DateTime.now().add(const Duration(days: 5, hours: 3)).toUtc().toIso8601String();
      final s = await _pump(t, const CompaniesListScreen(), platform: _FakePlatform(companies: [
        _company(status: 'trialing', trial: trial, total: 2),
        _company(id: 'o2', name: 'Tin Stays', status: 'suspended', plan: 'starter', props: 0, total: 2),
      ]));
      expect(find.text('Seaview Group'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('GROWTH'), findsOneWidget);
      expect(find.text('trialing'), findsOneWidget);
      expect(find.text('5d left'), findsOneWidget);
      expect(find.text('suspended'), findsOneWidget);
      expect(find.text('11 · 37'), findsWidgets);
      expect(s.platform.calls, contains('companies::all:0'));
      expect(t.takeException(), isNull);
    });

    testWidgets('search and filter go to the server', (t) async {
      final s = await _pump(t, const CompaniesListScreen(), platform: _FakePlatform(companies: [_company(), _company(id: 'o2', name: 'Tin Stays')]));
      await t.enterText(find.byType(TextField), 'tin');
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 100));
      expect(s.platform.calls, contains('companies:tin:all:0'));
      expect(find.text('Tin Stays'), findsOneWidget);
      expect(find.text('Seaview Group'), findsNothing);

      await t.tap(find.text('Suspended'));
      await t.pump(const Duration(milliseconds: 200));
      expect(s.platform.calls.last, 'companies:tin:suspended:0');
    });

    testWidgets('a database without the functions says what to do', (t) async {
      await _pump(t, const CompaniesListScreen(), platform: _FakePlatform(fail: Exception('PGRST202 superadmin_list_companies')));
      expect(find.textContaining('not installed'), findsOneWidget);
      expect(find.textContaining('20261023000004'), findsOneWidget);
    });

    testWidgets('narrow windows stack the rows', (t) async {
      await _pump(t, const CompaniesListScreen(), platform: _FakePlatform(companies: [_company()]), width: 760);
      expect(find.text('Seaview Group'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Properties page', () {
    testWidgets('lists every property with its company, usage and activity', (t) async {
      await _pump(t, const SuperadminPropertiesScreen(), platform: _FakePlatform(properties: [_property(), _property(id: 'p2', name: 'Harbour Grill', type: 'restaurant')]));
      expect(find.text('Seaview Hotel'), findsOneWidget);
      expect(find.text('Harbour Grill'), findsOneWidget);
      expect(find.text('Seaview Group'), findsWidgets);
      expect(find.text('12 · 6'), findsWidgets);
      expect(find.text('Properties'), findsWidgets);
      expect(find.text('7'), findsOneWidget, reason: 'the platform total from the overview');
      expect(t.takeException(), isNull);
    });

    testWidgets('search and filters reach the server', (t) async {
      final s = await _pump(t, const SuperadminPropertiesScreen(), platform: _FakePlatform(properties: [_property(), _property(id: 'p2', name: 'Harbour Grill')]));
      await t.enterText(find.byType(TextField), 'harbour');
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 100));
      expect(s.platform.calls, contains('properties:harbour:all:-:0'));
      await t.tap(find.text('Restaurants'));
      await t.pump(const Duration(milliseconds: 200));
      expect(s.platform.calls.last, 'properties:harbour:restaurant:-:0');
    });

    testWidgets('clicking a property opens its detail with people, bookings and activity', (t) async {
      final s = await _pump(t, const SuperadminPropertiesScreen(), platform: _FakePlatform(properties: [_property()]));
      await t.tap(find.text('Seaview Hotel'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.platform.calls, contains('property:p1'));
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('1 Beach Rd, Galle, LK'), findsOneWidget);
      expect(find.text('direct, airbnb'), findsOneWidget);
      expect(find.text('available  9'), findsOneWidget);
      expect(find.textContaining('People (2)'), findsOneWidget);

      await t.tap(find.textContaining('People ('));
      await t.pumpAndSettle();
      expect(find.text('Bob Stone'), findsOneWidget);
      expect(find.text('Company owners and managers (1)'), findsOneWidget);

      await t.tap(find.text('Bookings & orders'));
      await t.pumpAndSettle();
      expect(find.text('BK-0042'), findsOneWidget);
      expect(find.text('ORD-77'), findsOneWidget);
      expect(find.textContaining('Guest names and contact details are not shown'), findsOneWidget);

      await t.tap(find.textContaining('Activity ('));
      await t.pumpAndSettle();
      expect(s.users.calls, contains('activity:-:-:p1'), reason: 'the property tab asks for that property only');
      expect(t.takeException(), isNull);
    });

    testWidgets('missing functions are explained', (t) async {
      await _pump(t, const SuperadminPropertiesScreen(), platform: _FakePlatform(fail: Exception('PGRST202 superadmin_list_properties')));
      expect(find.textContaining('not installed'), findsOneWidget);
    });
  });

  group('Company insight', () {
    testWidgets('shows plan usage against limits, totals, people, properties and payments', (t) async {
      await _pump(t, const CompanyInsightView(orgId: 'o1'));
      expect(find.text('Growth plan'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('6 of 5'), findsOneWidget, reason: 'over the user limit');
      expect(find.text('20 · unlimited'), findsOneWidget);
      expect(find.text('Seaview Hotel'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsWidgets);
      expect(find.text('cook_01'), findsOneWidget, reason: 'a username, not the synthetic address');
      expect(find.text('LKR 7,999'), findsOneWidget);
      expect(find.textContaining('4 days left'), findsOneWidget);
      expect(find.text('Created a booking'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a property in the list opens its detail', (t) async {
      final s = await _pump(t, const CompanyInsightView(orgId: 'o1'));
      await t.tap(find.text('Seaview Hotel'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(s.platform.calls, contains('property:p1'));
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('failure shows the install hint, not a trace', (t) async {
      await _pump(t, const CompanyInsightView(orgId: 'o1'), platform: _FakePlatform(fail: Exception('PGRST202 superadmin_company_detail')));
      expect(find.textContaining('20261023000004'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Dashboard panel', () {
    testWidgets('shows the platform numbers, busiest companies and trials ending', (t) async {
      await _pump(t, const SingleChildScrollView(child: PlatformOverviewPanel()));
      expect(find.text('Platform activity'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Text && w.data == '22' && w.style?.fontSize == 20), findsOneWidget, reason: 'the registered-users figure (chart day labels may also read 22)');
      expect(find.text('9 active this week'), findsOneWidget);
      expect(find.text('1,250,000'), findsOneWidget);
      expect(find.text('Seaview Group'), findsOneWidget);
      expect(find.text('320 actions'), findsOneWidget);
      expect(find.text('Tin Stays'), findsOneWidget);
      expect(find.text('trial expired  1'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('one line when the functions are missing; the dashboard carries on', (t) async {
      await _pump(t, const SingleChildScrollView(child: PlatformOverviewPanel()), platform: _FakePlatform(fail: Exception('PGRST202 superadmin_platform_overview')));
      expect(find.textContaining('needs supabase/migrations/20261023000004'), findsOneWidget);
    });
  });

  group('Activity filtered by property', () {
    testWidgets('passes the property to the server', (t) async {
      final s = await _pump(t, const SingleChildScrollView(child: ActivityList(propertyId: 'p9')));
      expect(s.users.calls.first, 'activity:-:-:p9');
    });
  });
}
