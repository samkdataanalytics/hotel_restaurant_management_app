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
import '../dashboard_screen.dart';
import '../checkins_screen.dart';
import '../rooms_screen.dart';
import '../reservations_screen.dart';
import '../financials_screen.dart';
import '../expenses_management_screen.dart';
import '../pos_screen.dart';
import '../table_floor_screen.dart';
import '../kitchen_screen.dart';
import '../restaurant_management_screen.dart';
import '../orders_screen.dart';
import '../restaurant_analytics_screen.dart';
import '../cancellations_refunds_screen.dart';
import '../users_management_screen.dart';

// ─── Page list (flat index-addressed) ────────────────────────────────────────

const List<Widget> _pages = [
  // HOTEL (0–5)
  DashboardScreen(),
  CheckinsScreen(),
  RoomsScreen(),
  ReservationsScreen(),
  FinancialsScreen(),
  ExpensesManagementScreen(),
  // RESTAURANT (6–12)
  PosScreen(),
  TableFloorScreen(),
  KitchenScreen(),
  RestaurantManagementScreen(),
  OrdersScreen(),
  RestaurantAnalyticsScreen(),
  CancellationsRefundsScreen(),
  // TEAM (13)
  UsersManagementScreen(),
];

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
    _NavItem(Icons.people_alt_rounded, 'Team Members', 13),
  ],
);

// ─── App Shell ────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  bool _isInitializing = true;
  String? _initError;
  // Permission state for the current user on the active property
  bool _isPropertyManager = true; // assume true until loaded (safe default)
  bool _isPropertyOwner   = true; // owner = full admin (manages team + properties)
  Map<String, PrivilegeLevel> _userPermissions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      final authState = ref.read(authProvider).valueOrNull;
      final properties = authState?.properties ?? [];

      OrgProperty? activeProperty;

      // Try to restore the previously active property
      final saved = await OrganizationService().getActiveProperty();
      if (saved != null && properties.any((p) => p.id == saved.id)) {
        activeProperty = saved;
      } else if (properties.isNotEmpty) {
        activeProperty = properties.first;
      }

      if (activeProperty != null) {
        await _applyActiveProperty(activeProperty);
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
          if (activeProperty != null && !activeProperty.isHotel) {
            _selectedIndex = 6; // default to POS for restaurant-only
          }
        });
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
    // Persist to shared prefs
    await OrganizationService().setActivePropertyId(property.id);

    // Update Riverpod active property notifier
    ref.read(activePropertyProvider.notifier).setProperty(property);

    // Sync to legacy Provider-based HotelSession so existing screens work
    if (mounted) {
      final session =
          provider_pkg.Provider.of<HotelSession>(context, listen: false);
      await session.setHotelId(property.id);
    }

    // Sync to singleton services
    BookingService().hotelId    = property.id;
    RestaurantService().hotelId = property.id;

    // Load current user's role + permissions for this property
    await _loadUserPermissions(property.id);
  }

  Future<void> _loadUserPermissions(String propertyId) async {
    final role = await StaffService().getMyRoleForProperty(propertyId);
    // owner  = created the property (hotel_users) — full admin including team mgmt
    // manager = promoted staff member — full operational access, no team mgmt
    // staff   = limited to their assigned permissions
    // null    = not found in any table → treat as owner (e.g. during onboarding)
    final isOwner   = role == null || role == 'owner';
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

  Future<void> _switchToProperty(OrgProperty property) async {
    await _applyActiveProperty(property);

    setState(() {
      // Default to hotel dashboard or POS depending on type
      _selectedIndex = property.isHotel ? 0 : 6;
    });
  }

  List<_NavSection> _activeSections(OrgProperty? property) {
    // Determine raw sections based on property type
    List<_NavSection> rawSections;
    if (property == null) {
      rawSections = [_hotelSection];
    } else if (property.isHotel && property.isRestaurant) {
      rawSections = [_hotelSection, _restaurantSection];
    } else if (property.isRestaurant) {
      rawSections = [_restaurantSection];
    } else {
      rawSections = [_hotelSection];
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

    // When the active property changes (e.g. after adding a new property),
    // re-apply it so HotelSession, BookingService, RestaurantService update.
    ref.listen<OrgProperty?>(activePropertyProvider, (previous, next) {
      if (next != null && next.id != previous?.id) {
        _applyActiveProperty(next);
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

    final sections = _activeSections(activeProperty);

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(activeProperty, authState, sections),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(activeProperty, authState),
                Expanded(
                  key: ValueKey(activeProperty?.id ?? 'none'),
                  child: activeProperty?.status == 'inactive'
                      ? _InactivePropertyScreen(
                          property: activeProperty!,
                          onReactivate: () async {
                            await OrganizationService()
                                .updatePropertyStatus(activeProperty!.id, 'active');
                            await ref.read(authProvider.notifier).reload();
                            // Reload active property from DB
                            final updated = await OrganizationService()
                                .getActiveProperty();
                            if (updated != null) {
                              ref.read(activePropertyProvider.notifier)
                                  .setProperty(updated);
                            }
                          },
                        )
                      : _pages[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar(
    OrgProperty? activeProperty,
    AppAuthState? authState,
    List<_NavSection> sections,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: AppTheme.sidebarDark,
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
          _buildSidebarLogo(activeProperty),
          const Divider(color: Colors.white10, height: 1),
          if (_sidebarExpanded)
            _buildPropertySwitcher(authState, activeProperty),
          if (_sidebarExpanded)
            const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: sections
                    .map((section) => _buildSection(section))
                    .toList(),
              ),
            ),
          ),
          _buildSidebarFooter(authState),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo(OrgProperty? property) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarExpanded ? 20 : 12,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4A853), Color(0xFFE8C97A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hotel_rounded,
              color: Color(0xFF0F172A),
              size: 22,
            ),
          ),
          if (_sidebarExpanded) ...[
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

  Widget _buildSection(_NavSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_sidebarExpanded)
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
        ...section.items.map((item) => _buildNavItem(item, section)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNavItem(_NavItem item, _NavSection section) {
    final isSelected = _selectedIndex == item.pageIndex;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _sidebarExpanded ? 10 : 8,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedIndex = item.pageIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 12 : 0,
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
              mainAxisAlignment: _sidebarExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? section.accent : Colors.white38,
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isSelected)
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

  Widget _buildSidebarFooter(AppAuthState? authState) {
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 1),

        // Add Property button — only for owners
        if (_isPropertyOwner) Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _sidebarExpanded ? 10 : 8,
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
                  horizontal: _sidebarExpanded ? 12 : 0,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: _sidebarExpanded
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
                    if (_sidebarExpanded) ...[
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

        // Logout
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _sidebarExpanded ? 10 : 8,
            vertical: 4,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _signOut,
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
                    const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Colors.white24,
                    ),
                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 12),
                      const Text(
                        'Logout',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
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

  Widget _buildTopBar(OrgProperty? property, AppAuthState? authState) {
    String typeBadgeLabel = '';
    Color typeBadgeColor = AppTheme.adminPrimary;

    if (property != null) {
      if (property.isHotel && property.isRestaurant) {
        typeBadgeLabel = 'Hotel + Restaurant';
        typeBadgeColor = AppTheme.goldPrimary;
      } else if (property.isRestaurant) {
        typeBadgeLabel = 'Restaurant';
        typeBadgeColor = AppTheme.restaurantAccent;
      } else {
        typeBadgeLabel = 'Hotel';
        typeBadgeColor = AppTheme.adminPrimary;
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
          // Property name
          if (property != null) ...[
            Text(
              property.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
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

          // Current user — show username for staff accounts, email otherwise
          if (authState?.email != null)
            Row(
              children: [
                const Icon(
                  Icons.account_circle_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Text(
                  (authState?.isStaffAccount ?? false)
                      ? authState!.email!.split('@').first
                      : authState!.email!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: AppTheme.warning, size: 24),
            const SizedBox(width: 10),
            const Text('Property Limit Reached'),
          ],
        ),
        content: const Text(
          'Your current plan does not allow adding more properties. '
          'Upgrade to Pro or Enterprise to unlock additional properties.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.adminPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Upgrade Plan'),
          ),
        ],
      ),
    );
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
        title: const Text('Delete Property'),
        content: Text(
          'Permanently delete "${p.name}"?\n\nAll rooms, bookings, and data for this property will be deleted. This cannot be undone.',
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
            ),
            child: const Text('Delete'),
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
        SnackBar(content: Text('Failed to delete property: $e')),
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
        width: 480,
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
