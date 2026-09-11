import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/staff_permission.dart';
import '../../providers/app_auth_provider.dart';
import '../../providers/property_scope.dart' show applyPropertyScope, resolvePropertyRole;
import '../../providers/service_providers.dart';
import '../../services/organization_service.dart';

/// Why the staff app cannot show a working screen yet.
enum StaffBlocker {
  /// Not signed in.
  signedOut,

  /// Signed in, but the account has no organisation, no property, an expired
  /// trial, or is a superadmin. All of those are resolved on the web panel.
  setupRequired,
}

/// Resolved, property-scoped session for the staff mobile app.
class StaffSessionState {
  final List<OrgProperty> properties;
  final OrgProperty? activeProperty;

  /// Resolved via [resolvePropertyRole] — not read straight off the DB column.
  final bool isOwner;
  final bool isManager;

  final Map<String, PrivilegeLevel> permissions;

  /// Non-null when the app cannot proceed — the router redirects on this.
  final StaffBlocker? blocker;

  /// Human-readable reason shown on the setup-required screen.
  final String? blockerReason;

  const StaffSessionState({
    this.properties = const [],
    this.activeProperty,
    this.isOwner = false,
    this.isManager = false,
    this.permissions = const {},
    this.blocker,
    this.blockerReason,
  });

  bool get hasMultipleProperties => properties.length > 1;

  /// True when [sectionKey] is at least viewable.
  bool canView(String sectionKey) =>
      isManager ||
      (permissions[sectionKey] ?? PrivilegeLevel.none) != PrivilegeLevel.none;

  /// True when [sectionKey] is writable.
  bool canEdit(String sectionKey) =>
      isManager ||
      (permissions[sectionKey] ?? PrivilegeLevel.none) == PrivilegeLevel.edit;
}

/// Loads the signed-in user's properties, scopes every tenant-aware singleton
/// to the active one, and resolves their role and section privileges.
///
/// This is the mobile counterpart of `AppShell._applyActiveProperty` +
/// `_loadUserPermissions`. It deliberately lives in mobile code — `AppShell`
/// is a web widget carrying sidebar chrome, badge polling and a `HotelSession`
/// dependency that the mobile app has no use for. The part that genuinely must
/// not diverge, the tenant-scoping fan-out, is shared via [applyPropertyScope].
///
/// Note this provider resolves to a loading state until permissions have
/// actually been read. Callers must not render a permission-gated surface off
/// the defaults in `staff_permission.dart`, which are permissive (`true`) and
/// would briefly show a waiter an owner-shaped UI.
class StaffSession extends AsyncNotifier<StaffSessionState> {
  @override
  Future<StaffSessionState> build() async {
    // Rebuild whenever auth changes (sign-in, sign-out, reload).
    final auth = await ref.watch(authProvider.future);

    if (!auth.isLoggedIn) {
      return const StaffSessionState(blocker: StaffBlocker.signedOut);
    }

    // Superadmin tooling is web-only by design.
    if (auth.isSuperadmin) {
      return const StaffSessionState(
        blocker: StaffBlocker.setupRequired,
        blockerReason:
            'Superadmin tools are available on the web panel only.',
      );
    }

    if (!auth.hasOrganization) {
      return const StaffSessionState(
        blocker: StaffBlocker.setupRequired,
        blockerReason:
            'Your account has no organisation yet. Finish setting it up on the '
            'web, then sign in here.',
      );
    }

    if (auth.isTrialExpired) {
      return const StaffSessionState(
        blocker: StaffBlocker.setupRequired,
        blockerReason:
            'This organisation\'s trial has ended. Choose a plan on the web to '
            'restore access.',
      );
    }

    final orgService = ref.read(organizationServiceProvider);

    // authProvider already resolved this via get_my_properties() while loading
    // the user context — reuse it rather than paying for a second round trip
    // on every cold start. Same reasoning as AppShell._initialize.
    final properties = auth.properties;

    if (properties.isEmpty) {
      return StaffSessionState(
        blocker: StaffBlocker.setupRequired,
        blockerReason: auth.isStaffAccount
            ? 'You are not assigned to a property yet. Ask a manager to add you.'
            : 'No property has been created yet. Add one on the web to get '
                'started.',
      );
    }

    // Restore the property last used on this device, falling back to the first.
    final savedId = await orgService.getActivePropertyId();
    final active = properties.firstWhere(
      (p) => p.id == savedId,
      orElse: () => properties.first,
    );

    return _scopeTo(active, properties);
  }

  /// Switch the active property and re-scope everything to it.
  Future<void> switchProperty(OrgProperty property) async {
    final current = state.valueOrNull;
    if (current?.activeProperty?.id == property.id) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _scopeTo(property, current?.properties ?? [property]),
    );
  }

  /// Re-read role and permissions for the active property without a full
  /// rebuild — used after a pull-to-refresh.
  Future<void> refreshPermissions() async {
    final current = state.valueOrNull;
    final active = current?.activeProperty;
    if (active == null) return;
    state = await AsyncValue.guard(
      () => _scopeTo(active, current!.properties),
    );
  }

  Future<StaffSessionState> _scopeTo(
    OrgProperty property,
    List<OrgProperty> properties,
  ) async {
    await ref.read(organizationServiceProvider).setActivePropertyId(property.id);

    // Keep the shared activePropertyProvider in step, so anything reused from
    // the common layer sees the same active property the web shell would set.
    ref.read(activePropertyProvider.notifier).setProperty(property);

    // Point every tenant-scoped singleton at this property BEFORE any read or
    // write. Missing one of these is a silent empty list or an RLS 42501.
    applyPropertyScope(
      bookingService: ref.read(bookingServiceProvider),
      restaurantService: ref.read(restaurantServiceProvider),
      propertyId: property.id,
    );

    final staffService = ref.read(staffServiceProvider);
    final rawRole = await staffService.getMyRoleForProperty(property.id);

    // Shared with the web shell — a null role means owner for a regular account
    // but staff for an @staff.internal account. Never re-derive this locally.
    final isStaffAccount =
        ref.read(authProvider).valueOrNull?.isStaffAccount ?? false;
    final resolved =
        resolvePropertyRole(role: rawRole, isStaffAccount: isStaffAccount);

    // Managers and owners bypass the section map entirely, matching how
    // create_staff_member skips writing permission rows for them.
    final permissions = resolved.isManager
        ? <String, PrivilegeLevel>{}
        : await staffService.getMyPermissions(property.id);

    // Publish into the shared privilege providers that canEditSection() and any
    // reused widget read from.
    ref.read(isPropertyManagerProvider.notifier).state = resolved.isManager;
    ref.read(isPropertyOwnerProvider.notifier).state = resolved.isOwner;
    ref.read(activeSectionPermissionsProvider.notifier).state = permissions;

    return StaffSessionState(
      properties: properties,
      activeProperty: property,
      isOwner: resolved.isOwner,
      isManager: resolved.isManager,
      permissions: permissions,
    );
  }
}

final staffSessionProvider =
    AsyncNotifierProvider<StaffSession, StaffSessionState>(StaffSession.new);
