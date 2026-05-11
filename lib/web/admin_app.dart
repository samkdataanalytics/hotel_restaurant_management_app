import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'checkins_screen.dart';
import 'rooms_screen.dart';
import 'reservations_screen.dart';
import 'financials_screen.dart';
import 'guest_registration_screen.dart';
import 'expenses_management_screen.dart';
import 'pos_screen.dart';
import 'kitchen_screen.dart';
import 'restaurant_management_screen.dart';
import 'orders_screen.dart';
import 'restaurant_analytics_screen.dart';
import 'cancellations_refunds_screen.dart';
import 'table_floor_screen.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.webTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/guest-registration')) {
          final uri = Uri.parse(settings.name!);
          final ref = uri.queryParameters['ref'];
          if (ref != null && ref.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => GuestRegistrationScreen(bookingRef: ref),
            );
          }
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}

// ─── Nav item model ──────────────────────────────────────────────────────────

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

// ─── Pages (flat, index-addressed) ──────────────────────────────────────────

const _pages = <Widget>[
  // HOTEL  (0–5)
  DashboardScreen(),
  CheckinsScreen(),
  RoomsScreen(),
  ReservationsScreen(),
  FinancialsScreen(),
  ExpensesManagementScreen(),
  // RESTAURANT (6–10)
  PosScreen(),
  KitchenScreen(),
  RestaurantManagementScreen(),
  OrdersScreen(),
  RestaurantAnalyticsScreen(),
  CancellationsRefundsScreen(),
  TableFloorScreen(),
];

const _sections = <_NavSection>[
  _NavSection(
    'HOTEL',
    Color(0xFFD4A853),   // gold
    Color(0x1AD4A853),
    [
      _NavItem(Icons.dashboard_rounded,      'Dashboard',    0),
      _NavItem(Icons.how_to_reg_rounded,     'Check-ins',    1),
      _NavItem(Icons.meeting_room_rounded,   'Rooms',        2),
      _NavItem(Icons.calendar_month_rounded, 'Reservations', 3),
      _NavItem(Icons.attach_money_rounded,   'Financials',   4),
      _NavItem(Icons.receipt_long_rounded,   'Expenses',     5),
    ],
  ),
  _NavSection(
    'RESTAURANT',
    AppTheme.restaurantAccent,
    Color(0x1AF97316),
    [
      _NavItem(Icons.point_of_sale_rounded,    'POS',        6),
      _NavItem(Icons.restaurant_menu_rounded,  'Kitchen',    7),
      _NavItem(Icons.menu_book_rounded,        'Restaurant', 8),
      _NavItem(Icons.receipt_long_rounded,          'Orders',       9),
      _NavItem(Icons.analytics_rounded,             'Analytics',    10),
      _NavItem(Icons.remove_circle_outline_rounded, 'Cancellations', 11),
      _NavItem(Icons.table_restaurant_rounded,       'Tables',        12),
    ],
  ),
];

// ─── Main layout ─────────────────────────────────────────────────────────────

class AdminLayout extends ConsumerStatefulWidget {
  const AdminLayout({super.key});

  @override
  ConsumerState<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends ConsumerState<AdminLayout> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    // Propagate hotel_id into singleton services so every write is scoped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hotelId = context.read<HotelSession>().hotelId;
      ref.read(bookingServiceProvider).hotelId    = hotelId;
      ref.read(restaurantServiceProvider).hotelId = hotelId;
    });
  }

  void _select(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width < 768 && _sidebarExpanded) {
      _sidebarExpanded = false;
    }

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  // ─── Sidebar ─────────────────────────────────────────

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: AppTheme.sidebarDark,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          _buildLogo(),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _sections.map((section) => _buildSection(section)).toList(),
              ),
            ),
          ),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 20 : 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4A853), Color(0xFFE8C97A)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.hotel_rounded, color: Color(0xFF0F172A), size: 22),
          ),
          if (_sidebarExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Consumer<HotelSession>(
                builder: (_, session, __) => Text(
                  session.settings?.displayName.isNotEmpty == true
                      ? session.settings!.displayName
                      : 'HotRest Management',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(_NavSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label (only when expanded)
        if (_sidebarExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: section.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(section.label,
                    style: TextStyle(
                      color: section.accent.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Center(
              child: Container(width: 28, height: 1.5, color: section.accent.withOpacity(0.3)),
            ),
          ),
        // Nav items
        ...section.items.map((item) => _buildNavItem(item, section)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildNavItem(_NavItem item, _NavSection section) {
    final isSelected = _selectedIndex == item.pageIndex;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 10 : 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _select(item.pageIndex),
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
                  ? Border.all(color: section.accent.withOpacity(0.25), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? section.accent : Colors.white38,
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: section.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 1),
        // Toggle collapse button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebarExpanded ? 12 : 0,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisAlignment: _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(
                      _sidebarExpanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.white24,
                    ),
                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 10),
                      const Text('Collapse', style: TextStyle(color: Colors.white24, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Logout
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _sidebarExpanded ? 10 : 8, vertical: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await context.read<HotelSession>().signOut();
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebarExpanded ? 12 : 0,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisAlignment: _sidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 20, color: Colors.white24),
                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 12),
                      const Text('Logout', style: TextStyle(color: Colors.white38, fontSize: 13)),
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
}
