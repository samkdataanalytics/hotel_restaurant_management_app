import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/providers/property_scope.dart';
import 'package:hotel_checkin/services/auth_identity.dart';

/// Tests for the logic shared between the web panel and the staff mobile app.
///
/// These two functions were extracted specifically so the two front ends could
/// not drift apart on them, and both are security-relevant: one decides what
/// identity a login attempt resolves to, the other decides whether someone is
/// treated as a manager. Pinning the behaviour here is what makes "shared"
/// mean something.
void main() {
  group('resolveSignInEmail', () {
    test('passes an email through untouched', () {
      expect(
        resolveSignInEmail('owner@hotel.com'),
        'owner@hotel.com',
      );
    });

    test('builds the synthetic staff address from a bare username', () {
      expect(resolveSignInEmail('maria'), 'maria@staff.internal');
    });

    test('does not double-suffix an address already on the staff domain', () {
      expect(
        resolveSignInEmail('maria@staff.internal'),
        'maria@staff.internal',
      );
    });

    test('treats a username containing digits or underscores as a username', () {
      expect(resolveSignInEmail('maria_02'), 'maria_02@staff.internal');
    });
  });

  group('resolvePropertyRole', () {
    test('owner role grants owner and manager', () {
      final r = resolvePropertyRole(role: 'owner', isStaffAccount: false);
      expect(r.isOwner, isTrue);
      expect(r.isManager, isTrue);
    });

    test('manager role grants manager but not owner', () {
      final r = resolvePropertyRole(role: 'manager', isStaffAccount: true);
      expect(r.isOwner, isFalse);
      expect(r.isManager, isTrue);
    });

    test('staff role grants neither', () {
      final r = resolvePropertyRole(role: 'staff', isStaffAccount: true);
      expect(r.isOwner, isFalse);
      expect(r.isManager, isFalse);
    });

    test('a regular account with no role row is the org owner', () {
      // Org owners legitimately have no property_staff row.
      final r = resolvePropertyRole(role: null, isStaffAccount: false);
      expect(r.isOwner, isTrue);
      expect(r.isManager, isTrue);
    });

    test('a staff account with an unreadable role falls back to staff', () {
      // The important one: a failed role read must never escalate a staff
      // account to manager, which would hand it every section.
      final r = resolvePropertyRole(role: null, isStaffAccount: true);
      expect(r.isOwner, isFalse);
      expect(r.isManager, isFalse);
    });

    test('a staff account is never owner, even if the row says owner', () {
      // getMyRoleForProperty reads hotel_users as well as property_staff, so an
      // 'owner' string can reach here for an @staff.internal account.
      final r = resolvePropertyRole(role: 'owner', isStaffAccount: true);
      expect(r.isOwner, isFalse);
    });
  });
}
