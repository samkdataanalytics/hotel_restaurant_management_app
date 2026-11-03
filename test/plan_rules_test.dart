import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/providers/app_auth_provider.dart';
import 'package:hotel_checkin/services/organization_service.dart';
import 'package:hotel_checkin/web/suspended_screen.dart';

Organization _org(String status, {String? trialEnds, String name = 'Seaview Group'}) => Organization.fromRow({
      'id': 'o1',
      'name': name,
      'slug': 'seaview',
      'plan': 'growth',
      'status': status,
      'created_at': '2026-01-01T00:00:00Z',
      'trial_ends_at': trialEnds,
    });

AppAuthState _state(Organization? org, {bool admin = false, bool loggedIn = true}) =>
    AppAuthState(isLoading: false, isLoggedIn: loggedIn, isSuperadmin: admin, organization: org);

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this._s);
  final AppAuthState _s;
  bool signedOut = false;

  @override
  Future<AppAuthState> build() async => _s;

  @override
  Future<void> signOut() async => signedOut = true;
}

void main() {
  group('suspension', () {
    test('only a suspended company is suspended', () {
      expect(_org('suspended').isSuspended, isTrue);
      for (final s in ['active', 'trialing', 'trial_expired']) {
        expect(_org(s).isSuspended, isFalse, reason: s);
      }
    });

    test('the signed-in user is locked out only when their own company is suspended', () {
      expect(_state(_org('suspended')).isSuspended, isTrue);
      expect(_state(_org('active')).isSuspended, isFalse);
      expect(_state(null).isSuspended, isFalse, reason: 'no company yet: onboarding, not suspension');
      expect(_state(_org('suspended'), loggedIn: false).isSuspended, isFalse);
      expect(_state(_org('suspended'), admin: true).isSuspended, isFalse, reason: 'a superadmin is never locked out');
    });

    test('an expired trial is not suspension (it keeps its own read-only rules)', () {
      final s = _state(_org('trial_expired'));
      expect(s.isSuspended, isFalse);
      expect(s.isTrialExpired, isTrue);
    });

    test('the router rule sends everything but the notice to the notice', () {
      for (final loc in ['/app/dashboard', '/app/rooms', '/onboarding', '/property-setup', '/accept-invite', '/app/upgrade']) {
        expect(suspensionRedirect(suspended: true, location: loc), kSuspendedPath, reason: loc);
      }
      expect(suspensionRedirect(suspended: true, location: kSuspendedPath), isNull, reason: 'no redirect loop');
      expect(suspensionRedirect(suspended: false, location: '/app/dashboard'), isNull);
    });

    testWidgets('the notice names the company and signs the user out', (t) async {
      final fake = _FakeAuth(_state(_org('suspended')));
      await t.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: SuspendedScreen()),
      ));
      await t.pump();
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.textContaining('Seaview Group'), findsOneWidget);
      await t.tap(find.text('Sign out'));
      await t.pump();
      expect(fake.signedOut, isTrue);
    });

    testWidgets('the notice still reads well before the company has loaded', (t) async {
      await t.pumpWidget(ProviderScope(
        overrides: [authProvider.overrideWith(() => _FakeAuth(_state(null)))],
        child: const MaterialApp(home: SuspendedScreen()),
      ));
      await t.pump();
      expect(find.textContaining('has been suspended'), findsOneWidget);
    });
  });
}
