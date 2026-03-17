import 'package:flutter/material.dart';
import '../app_theme.dart';
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

/// Main admin layout with sidebar navigation
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  final _pages = const [
    DashboardScreen(),
    CheckinsScreen(),
    RoomsScreen(),
    ReservationsScreen(),
    PosScreen(),
    KitchenScreen(),
    FinancialsScreen(),
    ExpensesManagementScreen(),
  ];

  final _navItems = const [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.how_to_reg_rounded, 'Check-ins'),
    _NavItem(Icons.meeting_room_rounded, 'Rooms'),
    _NavItem(Icons.calendar_month_rounded, 'Reservations'),
    _NavItem(Icons.point_of_sale_rounded, 'POS'),
    _NavItem(Icons.restaurant_menu_rounded, 'Kitchen'),
    _NavItem(Icons.attach_money_rounded, 'Financials'),
    _NavItem(Icons.receipt_long_rounded, 'Expenses'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768 && _sidebarExpanded) {
      _sidebarExpanded = false;
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
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
                // Header
                Container(
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
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.goldPrimary,
                              AppTheme.goldLight,
                            ],
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
                        const Expanded(
                          child: Text(
                            'Grand Luxe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // Nav items
                const SizedBox(height: 12),
                ..._navItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _selectedIndex == index;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _sidebarExpanded ? 12 : 8,
                      vertical: 2,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: _sidebarExpanded ? 14 : 0,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.adminPrimary.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: _sidebarExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icon,
                                size: 22,
                                color: isSelected
                                    ? AppTheme.adminPrimary
                                    : Colors.white54,
                              ),
                              if (_sidebarExpanded) ...[
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Toggle sidebar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    onPressed: () =>
                        setState(() => _sidebarExpanded = !_sidebarExpanded),
                    icon: Icon(
                      _sidebarExpanded
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: Colors.white38,
                    ),
                  ),
                ),

                // Logout button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _sidebarExpanded ? 12 : 8,
                    vertical: 8,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 14 : 0,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: _sidebarExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded,
                                size: 22, color: Colors.white38),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              const Text(
                                'Logout',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 14),
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
            ),
          ),

          // Content area
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}
