import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import '../../providers/hotel_session.dart';
import '../../services/organization_service.dart';
import '../../services/booking_service.dart';
import '../../services/restaurant_service.dart';
import '../../models/staff_permission.dart';
import '../../services/staff_service.dart';
import '../edit_property_dialog.dart';
import '../../services/notification_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/upgrade_plan_dialog.dart';

// ─── Route map (pageIndex ↔ URL path) ────────────────────────────────────────

const Map<int, String> kPageRoutes = {
  0:  '/app/dashboard',
  1:  '/app/check-ins',
  2:  '/app/rooms',
  3:  '/app/reservations',
  4:  '/app/financials',
  5:  '/app/expenses',
  6:  '/app/pos',
  7:  '/app/tables',
  8:  '/app/kitchen',
  9:  '/app/restaurant',
  10: '/app/orders',
  11: '/app/analytics',
  12: '/app/cancellations',
  13: '/app/team',
  14: '/app/shifts',
};

const Map<String, int> kRoutePageIndex = {
  '/app/dashboard':     0,
  '/app/check-ins':     1,
  '/app/rooms':         2,
  '/app/reservations':  3,
  '/app/financials':    4,
  '/app/expenses':      5,
  '/app/pos':           6,
  '/app/tables':        7,
  '/app/kitchen':       8,
  '/app/restaurant':    9,
  '/app/orders':        10,
  '/app/analytics':     11,
  '/app/cancellations': 12,
  '/app/team':          13,
  '/app/shifts':        14,
};

// ─── Nav models ───────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final int pageIndex;
  const _NavItem(this.icon, this.label, this.pageIndex);
}

class _NavSection {
  final String label;
  final Color accent;
  final Color accentBg;
  final List<_NavItem> items;
  const _NavSection(this.label, this.accent, this.accentBg, this.items);
}

const _hotelSection = _NavSection(
  'HOTEL',
  Color(0xFFD4A853),
  Color(0x1AD4A853),
  [
    _NavItem(Icons.dashboard_rounded,      'Dashboard',    0),
    _NavItem(Icons.how_to_reg_rounded,     'Check-Ins',    1),
    _NavItem(Icons.meeting_room_rounded,   'Rooms',        2),
    _NavItem(Icons.calendar_month_rounded, 'Reservations', 3),
    _NavItem(Icons.attach_money_rounded,   'Financials',   4),
    _NavItem(Icons.receipt_long_rounded,   'Expenses',     5),
  ],
);

const _restaurantSection = _NavSection(
  'RESTAURANT',
  AppTheme.restaurantAccent,
  Color(0x1AF97316),
  [
    _NavItem(Icons.point_of_sale_rounded,         'POS',           6),
    _NavItem(Icons.table_restaurant_rounded,      'Tables',        7),
    _NavItem(Icons.restaurant_menu_rounded,       'Kitchen',       8),
    _NavItem(Icons.menu_book_rounded,             'Restaurant',    9),
    _NavItem(Icons.receipt_long_rounded,          'Orders',       10),
    _NavItem(Icons.analytics_rounded,             'Analytics',    11),
    _NavItem(Icons.remove_circle_outline_rounded, 'Cancellations',12),
  ],
);

const _teamSection = _NavSection(
  'TEAM',
  Color(0xFF818CF8), // indigo-400
  Color(0x1A818CF8),
  [
    _NavItem(Icons.people_alt_rounded,    'Team Members', 13),
    _NavItem(Icons.calendar_month_rounded, 'Shifts',      14),
  ],
);

// ─── App Shell ────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarExpanded = true;
  bool _isInitializing = true;
  bool _noProperties   = false; // true when a staff user has no assigned properties
  String? _initError;
  // Permission state for the current user on the active property
  bool _isPropertyManager = true; // assume true until loaded (safe default)
  bool _isPropertyOwner   = true; // owner = full admin (manages team + properties)
  Map<String, PrivilegeLevel> _userPermissions = {};
  // Badge counts: pageIndex → count (only populated for actionable items)
  Map<int, int> _badgeCounts = {};
  Timer? _badgeRefreshTimer;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Notification service — re-created when the active property changes
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    // Refresh badge counts every 30 seconds in the background
    _badgeRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadBadgeCounts(),
    );
  }

  @override
  void dispose() {
    _badgeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Use .future so we wait for the auth to fully resolve on browser reload.
      // ref.read(authProvider).valueOrNull returns null while loading, which
      // would cause properties=[] and the user landing on page 0 every time.
      final authState = await ref.read(authProvider.future);
      final properties = authState.properties;

      OrgProperty? activeProperty;

      // Resolve the active property from the already-loaded list — no extra
      // DB round-trip. SharedPreferences is local and fast.
      final savedId = await OrganizationService().getActivePropertyId();
      if (savedId != null) {
        try {
          activeProperty = properties.firstWhere((p) => p.id == savedId);
        } catch (_) {
          // saved ID no longer valid (property deleted/unassigned)
        }
      }
      activeProperty ??= properties.isNotEmpty ? properties.first : null;

      if (activeProperty != null) {
        await _applyActiveProperty(activeProperty);
      }

      // No properties at all — staff account with no assignment yet
      if (activeProperty == null && properties.isEmpty) {
        if (mounted) setState(() { _isInitializing = false; _noProperties = true; });
        return;
      }

      // Navigate to the default route for this user/property now that
      // permissions are loaded. Only redirect if still on a generic app path.
      final defaultRoute = activeProperty != null
          ? _defaultRoute(activeProperty)
          : '/app/dashboard';

      if (mounted) {
        setState(() { _isInitializing = false; });
        final currentPath = GoRouterState.of(context).uri.path;
        if (currentPath == '/app' || currentPath == '/app/dashboard') {
          context.go(defaultRoute);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  /// Persists, propagates, and syncs [property] across all state holders.
  Future<void> _applyActiveProperty(OrgProperty property) async {
    // Persist to shared prefs (safe even if unmounted — no widget dependency)
    await OrganizationService().setActivePropertyId(property.id);

    // Guard: widget may have been disposed during the async gap above
    if (!mounted) return;

    ref.read(activePropertyProvider.notifier).setProperty(property);

    // Point singleton services at the new property before any parallel work
    BookingService().hotelId    = property.id;
    RestaurantService().hotelId = property.id;

    // Run session sync (fetches hotel_settings) and permission load in parallel
    // — they are independent DB calls, no ordering required.
    if (mounted) {
      final session =
          provider_pkg.Provider.of<HotelSession>(context, listen: false);
      await Future.wait([
        session.setHotelId(property.id),
        _loadUserPermissions(property.id),
      ]);
    } else {
      return; // widget disposed — bail out
    }

    if (!mounted) return;

    // Refresh badge counts now that services are pointed at the new property
    _loadBadgeCounts();

    // Spin up notification service for the new property + run housekeeping check
    if (mounted) {
      setState(() {
        _notificationService = NotificationService(property.id);
      });
      _notificationService!.checkHousekeeping();
    }
  }

  Future<void> _loadUserPermissions(String propertyId) async {
    final role = await StaffService().getMyRoleForProperty(propertyId);
    // owner   = created the property (hotel_users) — full admin including team mgmt
    // manager = promoted staff member — full operational access, no team mgmt
    // staff   = limited to their assigned permissions
    // null    = not found in any table:
    //   • regular accounts (org owners) → treat as owner
    //   • staff accounts (@staff.internal) → role wasn't readable; default to 'staff'
    //     so they land on their first permitted page, not the hotel Dashboard.
    final isStaffAccount =
        ref.read(authProvider).valueOrNull?.isStaffAccount ?? false;
    final isOwner   = !isStaffAccount && (role == null || role == 'owner');
    final isManager = isOwner || role == 'manager';
    Map<String, PrivilegeLevel> permissions = {};
    if (!isManager) {
      permissions = await StaffService().getMyPermissions(propertyId);
    }
    if (mounted) {
      setState(() {
        _isPropertyOwner   = isOwner;
        _isPropertyManager = isManager;
        _userPermissions   = permissions;
      });
      ref.read(isPropertyOwnerProvider.notifier).state   = isOwner;
      ref.read(isPropertyManagerProvider.notifier).state = isManager;
      ref.read(activeSectionPermissionsProvider.notifier).state = permissions;
    }
  }

  /// Fetches counts for nav items that need attention badges.
  /// Uses targeted ID-only queries filtered server-side — no full table scans.
  /// Runs silently — failures are swallowed so they never break the shell.
  Future<void> _loadBadgeCounts() async {
    if (!mounted) return;
    try {
      final results = await Future.wait<int>([
        BookingService().countPendingArrivalsToday(),
        RestaurantService().countActiveKitchenOrdersToday(),
      ]);

      final pendingArrivals = results[0];
      final activeKitchen   = results[1];

      if (!mounted) return;
      setState(() {
        _badgeCounts = {
          if (pendingArrivals > 0) 1: pendingArrivals,
          if (activeKitchen   > 0) 8: activeKitchen,
        };
      });
    } catch (_) {
      // Non-critical — badge counts are best-effort
    }
  }

  Future<void> _switchToProperty(OrgProperty property) async {
    await _applyActiveProperty(property);
    final defaultRoute = _defaultRoute(property);
    if (mounted) {
      setState(() {});
      context.go(defaultRoute);
    }
  }

  /// Navigate to the URL for [pageIndex].
  void _navigateTo(int pageIndex) {
    final route = kPageRoutes[pageIndex] ?? '/app/dashboard';
    context.go(route);
  }

  /// Returns the default route for [property] based on the user's permissions.
  /// Finds the first visible nav item so restaurant-only staff land correctly.
  String _defaultRoute(OrgProperty property) {
    final sections = _activeSections(property);
    final firstItem = sections.expand((s) => s.items).firstOrNull;
    return kPageRoutes[firstItem?.pageIndex ?? 0] ?? '/app/dashboard';
  }

  /// Builds the hotel nav section with the property's brand color.
  _NavSection _hotelSectionFor(OrgProperty? property) {
    final accent = property != null
        ? hexToColor(property.primaryColor)
        : const Color(0xFFD4A853);
    return _NavSection(
      'HOTEL',
      accent,
      accent.withAlpha(26), // ~10% opacity
      _hotelSection.items,
    );
  }

  List<_NavSection> _activeSections(OrgProperty? property) {
    final hotelSec = _hotelSectionFor(property);

    // Determine raw sections based on property type
    List<_NavSection> rawSections;
    if (property == null) {
      rawSections = [hotelSec];
    } else if (property.isHotel && property.isRestaurant) {
      rawSections = [hotelSec, _restaurantSection];
    } else if (property.isRestaurant) {
      rawSections = [_restaurantSection];
    } else {
      rawSections = [hotelSec];
    }

    // Managers and owners see all operational sections + team members
    if (_isPropertyManager) {
      return [...rawSections, _teamSection];
    }

    // Staff: filter nav items by their privilege (hide 'none' sections)
    final filtered = rawSections
        .map((section) {
          final visibleItems = section.items.where((item) {
            final key = kSectionKeyByPageIndex[item.pageIndex];
            if (key == null) return true;
            return (_userPermissions[key] ?? PrivilegeLevel.none) !=
                PrivilegeLevel.none;
          }).toList();
          return _NavSection(
              section.label, section.accent, section.accentBg, visibleItems);
        })
        .where((s) => s.items.isNotEmpty)
        .toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final activeProperty = ref.watch(activePropertyProvider);
    final authState = ref.watch(authProvider).valueOrNull;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Re-apply only on an actual property *switch* (both previous and next
    // are non-null and different).  The initial set (null → property) is
    // already handled by _initialize, so we skip it here to avoid a
    // duplicate round of DB calls on every startup.
    ref.listen<OrgProperty?>(activePropertyProvider, (previous, next) {
      if (previous != null && next != null && next.id != previous.id) {
        unawaited(_applyActiveProperty(next));
      }
    });

    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.danger),
                const SizedBox(height: 16),
                Text(
                  'Failed to load: $_initError',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.adminTextMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _initError = null;
                    });
                    _initialize();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_noProperties) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 56, color: Color(0xFF475569)),
                const SizedBox(height: 20),
                const Text(
                  'No properties assigned',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account has not been assigned to any property yet.\nPlease contact your manager.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.adminTextMuted, height: 1.5),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sections = _activeSections(activeProperty);

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? Drawer(child: _buildSidebar(activeProperty, authState, sections, isDrawer: true)) : null,
      bottomNavigationBar: isMobile ? _buildBottomNav(activeProperty) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(activeProperty, authState, sections),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(activeProperty, authState, isMobile),
                Expanded(
                  key: ValueKey(activeProperty?.id ?? 'none'),
                  child: activeProperty?.status == 'inactive'
                      ? _InactivePropertyScreen(
                          property: activeProperty!,
                          onReactivate: () async {
                            await OrganizationService()
                                .updatePropertyStatus(activeProperty.id, 'active');
                            await ref.read(authProvider.notifier).reload();
                            final updated = await OrganizationService()
                                .getActiveProperty();
                            if (updated != null) {
                              ref.read(activePropertyProvider.notifier)
                                  .setProperty(updated);
                            }
                          },
                        )
                      : widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile bottom navigation ─────────────────────────────────────────────

  /// Returns up to 4 primary nav items for the mobile bottom bar.
  /// Uses _activeSections so only pages the current user has access to appear.
  List<_NavItem> _mobileNavItems(OrgProperty? property) {
    if (property == null) return [_hotelSection.items[0]];

    final sections = _activeSections(property);
    if (sections.isEmpty) return [];

    // For combined hotel+restaurant properties show 2 from each section (if
    // accessible), otherwise show the first 4 items from available sections.
    if (property.isHotel && property.isRestaurant) {
      final hotelItems = sections
          .where((s) => s.label == 'HOTEL')
          .expand((s) => s.items)
          .take(2)
          .toList();
      final restaurantItems = sections
          .where((s) => s.label == 'RESTAURANT')
          .expand((s) => s.items)
          .take(2)
          .toList();
      final combined = [...hotelItems, ...restaurantItems];
      if (combined.isNotEmpty) return combined.take(4).toList();
    }

    return sections.expand((s) => s.items).take(4).toList();
  }

  Widget _buildBottomNav(OrgProperty? activeProperty) {
    final navItems = _mobileNavItems(activeProperty);
    // Which bottom-nav tab is active? Falls back to the "More" slot (last)
    // if the currently viewed page is not in the shortcut list.
    final currentPath    = GoRouterState.of(context).uri.path;
    final currentPageIdx = kRoutePageIndex[currentPath] ?? -1;
    int selectedIdx = navItems.indexWhere((i) => i.pageIndex == currentPageIdx);
    if (selectedIdx < 0) selectedIdx = navItems.length; // "More" slot

    return BottomNavigationBar(
      currentIndex: selectedIdx.clamp(0, navItems.length),
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF0F172A),
      selectedItemColor: hexToColor(activeProperty?.primaryColor ?? '#D4A853'),
      unselectedItemColor: Colors.white38,
      selectedLabelStyle:
          const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      elevation: 8,
      onTap: (idx) {
        if (idx < navItems.length) {
          _navigateTo(navItems[idx].pageIndex);
        } else {
          // "More" — open the full sidebar drawer
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      items: [
        ...navItems.map((item) {
          final count = _badgeCounts[item.pageIndex] ?? 0;
          return BottomNavigationBarItem(
            icon: count > 0
                ? Badge(
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 9),
                    ),
                    backgroundColor: AppTheme.danger,
                    child: Icon(item.icon),
                  )
                : Icon(item.icon),
            label: item.label,
          );
        }),
        const BottomNavigationBarItem(
          icon: Icon(Icons.apps_rounded),
          label: 'More',
        ),
      ],
    );
  }

  // ─── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar(
    OrgProperty? activeProperty,
    AppAuthState? authState,
    List<_NavSection> sections, {
    bool isDrawer = false,
  }) {
    final expanded = isDrawer ? true : _sidebarExpanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 240 : 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2540), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSidebarLogo(activeProperty, expanded),
          const Divider(color: Colors.white10, height: 1),
          if (expanded)
            _buildPropertySwitcher(authState, activeProperty),
          if (expanded)
            const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: sections
                    .map((section) => _buildSection(section, expanded))
                    .toList(),
              ),
            ),
          ),
          _buildSidebarFooter(authState, expanded),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo(OrgProperty? property, bool expanded) {
    final logoUrl = provider_pkg.Provider.of<HotelSession>(context, listen: false)
        .settings
        ?.logoUrl ?? '';
    final logoSize = expanded ? 40.0 : 32.0;
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 20 : 12,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: logoUrl.isNotEmpty
                ? Image.network(
                    logoUrl,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      'assets/images/hotrest_logo.webp',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  )
                : Image.asset(
                    'assets/images/hotrest_logo.webp',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                  ),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                property?.name ?? 'HotRest',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertySwitcher(
    AppAuthState? authState,
    OrgProperty? activeProperty,
  ) {
    final properties = authState?.properties ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == '__manage__') {
            _showManagePropertiesDialog(properties, activeProperty);
          } else {
            final p = properties.firstWhere((p) => p.id == value);
            _switchToProperty(p);
          }
        },
        tooltip: 'Switch property',
        offset: const Offset(0, 44),
        itemBuilder: (_) => [
          ...properties.map((p) {
            final isActive = p.id == activeProperty?.id;
            return PopupMenuItem<String>(
              value: p.id,
              child: Row(
                children: [
                  Icon(
                    p.isHotel && p.isRestaurant
                        ? Icons.business_rounded
                        : p.isRestaurant
                            ? Icons.restaurant_rounded
                            : Icons.hotel_rounded,
                    size: 18,
                    color: isActive
                        ? AppTheme.adminPrimary
                        : p.status == 'inactive'
                            ? AppTheme.adminTextMuted.withOpacity(0.4)
                            : AppTheme.adminTextMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive
                                ? AppTheme.adminPrimary
                                : p.status == 'inactive'
                                    ? AppTheme.adminTextMuted
                                    : const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.status == 'inactive')
                          Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.warning,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(Icons.check_rounded, size: 16, color: AppTheme.adminPrimary),
                ],
              ),
            );
          }),
          // Only owners can manage (rename, deactivate) properties
          if (_isPropertyOwner) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: '__manage__',
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 10),
                  Text('Manage Properties', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded,
                  size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeProperty?.name ?? 'Select property',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down_rounded,
                  size: 18, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_NavSection section, bool expanded) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: section.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  section.label,
                  style: TextStyle(
                    color: section.accent.withOpacity(0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Center(
              child: Container(
                width: 28,
                height: 1.5,
                color: section.accent.withOpacity(0.3),
              ),
            ),
          ),
        ...section.items.map((item) => _buildNavItem(item, section, expanded)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNavItem(_NavItem item, _NavSection section, bool expanded) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isSelected  = currentPath == kPageRoutes[item.pageIndex];
    final count       = _badgeCounts[item.pageIndex] ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 8,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateTo(item.pageIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isSelected ? section.accentBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: section.accent.withOpacity(0.25), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: (expanded || MediaQuery.of(context).size.width < 768)
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                // Icon — with a small dot overlay when collapsed and count > 0
                expanded
                    ? Icon(item.icon, size: 20,
                          color: isSelected ? section.accent : Colors.white38)
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(item.icon, size: 20,
                              color: isSelected ? section.accent : Colors.white38),
                          if (count > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.danger,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.sidebarDark, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: section.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(AppAuthState? authState, bool expanded) {
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 1),

        // Add Property button — only for owners
        if (_isPropertyOwner) Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 10 : 8,
            vertical: 4,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _onAddProperty(authState),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 12 : 0,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'Add Property',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sidebar collapse toggle
        if (MediaQuery.of(context).size.width >= 768)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    setState(() => _sidebarExpanded = !_sidebarExpanded),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebarExpanded ? 12 : 0,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: _sidebarExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      _sidebarExpanded
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white24,
                    ),
                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'Collapse',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),



        const SizedBox(height: 12),
      ],
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(OrgProperty? property, AppAuthState? authState, bool isMobile) {
    String typeBadgeLabel = '';
    Color typeBadgeColor = AppTheme.adminPrimary;

    if (property != null) {
      final brandColor = hexToColor(property.primaryColor);
      if (property.isHotel && property.isRestaurant) {
        typeBadgeLabel = 'Hotel + Restaurant';
        typeBadgeColor = brandColor;
      } else if (property.isRestaurant) {
        typeBadgeLabel = 'Restaurant';
        typeBadgeColor = AppTheme.restaurantAccent;
      } else {
        typeBadgeLabel = 'Hotel';
        typeBadgeColor = brandColor;
      }
    }

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (isMobile) const SizedBox(width: 8),
          // Property name
          if (property != null) ...[
            Expanded(
              child: Text(
                property.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeBadgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeBadgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: typeBadgeColor,
                ),
              ),
            ),
          ] else
            const Text(
              'HotRest Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),

          const Spacer(),

          // Notification bell
          if (_notificationService != null) ...[
            NotificationBell(service: _notificationService!),
            const SizedBox(width: 8),
          ],

          // Current user — on mobile show only avatar icon; on desktop show name
          if (authState?.email != null)
            PopupMenuButton<String>(
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'account') {
                  context.go('/app/account');
                } else if (value == 'logout') {
                  _signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'account',
                  child: Row(
                    children: [
                      Icon(Icons.manage_accounts_rounded, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      const Text('Account Settings', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      const Text('Logout', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_rounded, size: 24, color: Color(0xFF94A3B8)),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Text(
                        (authState?.isStaffAccount ?? false)
                            ? authState!.email!.split('@').first
                            : authState!.email!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _onAddProperty(AppAuthState? authState) async {
    final orgId = authState?.organization?.id;
    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No organization found. Complete onboarding first.'),
        ),
      );
      return;
    }

    bool canAdd;
    try {
      canAdd = await OrganizationService().canAddProperty(orgId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking plan limit: $e')),
      );
      return;
    }

    if (!mounted) return;

    if (!canAdd) {
      _showUpgradeDialog();
      return;
    }

    context.go('/property-setup');
  }

  void _showUpgradeDialog() {
    showUpgradePlanDialog(context, ref, blockedResource: 'properties');
  }

  void _showManagePropertiesDialog(
    List<OrgProperty> properties,
    OrgProperty? activeProperty,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _ManagePropertiesDialog(
        properties: properties,
        activePropertyId: activeProperty?.id,
        onChanged: () async {
          await ref.read(authProvider.notifier).reload();
          // If the active property was deleted or deactivated, switch to first available
          final updated = ref.read(authProvider).valueOrNull?.properties ?? [];
          final stillActive = updated.any((p) => p.id == activeProperty?.id);
          if (!stillActive && updated.isNotEmpty) {
            await _switchToProperty(updated.first);
          }
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    context.go('/login');
  }
}

// ─── Inactive Property Screen ────────────────────────────────────────────────

class _InactivePropertyScreen extends StatefulWidget {
  final OrgProperty property;
  final Future<void> Function() onReactivate;
  const _InactivePropertyScreen({required this.property, required this.onReactivate});

  @override
  State<_InactivePropertyScreen> createState() => _InactivePropertyScreenState();
}

class _InactivePropertyScreenState extends State<_InactivePropertyScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pause_circle_rounded, size: 44, color: AppTheme.warning),
            ),
            const SizedBox(height: 24),
            Text(
              '${widget.property.name} is Inactive',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This property has been marked as inactive.\nAll features are locked until it is reactivated.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.adminTextMuted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        setState(() => _loading = true);
                        try {
                          await widget.onReactivate();
                        } catch (e) {
                          if (mounted) {
                            setState(() => _loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to reactivate: $e')),
                            );
                          }
                        }
                      },
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_circle_rounded, size: 18),
                label: const Text('Reactivate Property',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Manage Properties Dialog ─────────────────────────────────────────────────

class _ManagePropertiesDialog extends StatefulWidget {
  final List<OrgProperty> properties;
  final String? activePropertyId;
  final VoidCallback onChanged;

  const _ManagePropertiesDialog({
    required this.properties,
    required this.activePropertyId,
    required this.onChanged,
  });

  @override
  State<_ManagePropertiesDialog> createState() => _ManagePropertiesDialogState();
}

class _ManagePropertiesDialogState extends State<_ManagePropertiesDialog> {
  bool _loading = false;

  Future<void> _editProperty(OrgProperty p) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EditPropertyDialog(property: p),
    );
    if (saved != true || !mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _toggleStatus(OrgProperty p) async {
    final newStatus = p.status == 'active' ? 'inactive' : 'active';
    setState(() => _loading = true);
    try {
      await OrganizationService().updatePropertyStatus(p.id, newStatus);
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _confirmDelete(OrgProperty p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
            const SizedBox(width: 10),
            const Text('Deactivate Property'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deactivate "${p.name}"?',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• The property will be hidden from your dashboard',
                      style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• All bookings and historical data are preserved',
                      style: TextStyle(fontSize: 13)),
                  SizedBox(height: 4),
                  Text('• This can be reversed by contacting support',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await OrganizationService().deleteProperty(p.id);
      widget.onChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deactivate property: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.business_rounded, size: 22),
          SizedBox(width: 10),
          Text('Manage Properties'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.properties.map((p) {
                  final isActive = p.id == widget.activePropertyId;
                  final isPropertyActive = p.status == 'active';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? AppTheme.adminPrimary.withOpacity(0.4)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          p.isHotel && p.isRestaurant
                              ? Icons.business_rounded
                              : p.isRestaurant
                                  ? Icons.restaurant_rounded
                                  : Icons.hotel_rounded,
                          size: 20,
                          color: isPropertyActive
                              ? AppTheme.adminPrimary
                              : AppTheme.adminTextMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPropertyActive
                                          ? AppTheme.success.withOpacity(0.1)
                                          : AppTheme.warning.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPropertyActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isPropertyActive
                                            ? AppTheme.success
                                            : AppTheme.warning,
                                      ),
                                    ),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.adminPrimary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.adminPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Edit property details
                        Tooltip(
                          message: 'Edit property',
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppTheme.adminPrimary,
                            onPressed: () => _editProperty(p),
                          ),
                        ),
                        // Toggle active/inactive
                        Tooltip(
                          message: isPropertyActive ? 'Mark as Inactive' : 'Mark as Active',
                          child: IconButton(
                            icon: Icon(
                              isPropertyActive
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              color: isPropertyActive
                                  ? AppTheme.warning
                                  : AppTheme.success,
                            ),
                            onPressed: () => _toggleStatus(p),
                          ),
                        ),
                        // Delete
                        Tooltip(
                          message: 'Delete property',
                          child: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                            onPressed: () => _confirmDelete(p),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
