import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_theme.dart';
import '../../providers/app_auth_provider.dart';
import 'superadmin_dashboard.dart';
import 'companies_list_screen.dart';
import 'superadmin_plans_screen.dart';
import 'superadmin_leads_screen.dart';
import '../studio/studio_screen.dart';
import 'tracking/superadmin_properties_screen.dart';
import 'users/superadmin_users_screen.dart';

// ─── Nav item model ───────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final int pageIndex;
  const _NavItem(this.icon, this.label, this.pageIndex);
}

// ─── Shell ────────────────────────────────────────────────────────────────────

class SuperadminShell extends ConsumerStatefulWidget {
  const SuperadminShell({super.key});

  @override
  ConsumerState<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends ConsumerState<SuperadminShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  static const _pages = <Widget>[
    SuperadminDashboard(),
    CompaniesListScreen(),
    SuperadminPropertiesScreen(),
    SuperadminUsersScreen(),
    SuperadminPlansScreen(),
    SuperadminLeadsScreen(),
    StudioScreen(),
  ];

  static const _navItems = <_NavItem>[
    _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
    _NavItem(Icons.business_rounded, 'Companies', 1),
    _NavItem(Icons.apartment_rounded, 'Properties', 2),
    _NavItem(Icons.people_alt_rounded, 'Users', 3),
    _NavItem(Icons.layers_rounded, 'Plans', 4),
    _NavItem(Icons.mark_email_unread_rounded, 'Leads', 5),
    _NavItem(Icons.web_rounded, 'Website', 6),
  ];

  /// The website editor needs the width: it has three panes of its own.
  static const _studioIndex = 6;

  void _select(int index) => setState(() {
        _selectedIndex = index;
        if (index == _studioIndex) _sidebarExpanded = false;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  // ─── Sidebar ──────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: AppTheme.sidebarDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
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
                              color: AppTheme.brandOnDark,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SUPERADMIN',
                            style: TextStyle(
                              color: AppTheme.brandOnDark.withOpacity(0.9),
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
                          color: AppTheme.brandOnDark.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ..._navItems.map((item) => _buildNavItem(item)),
                  const SizedBox(height: 4),
                ],
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9B94), Color(0xFF3FBDB4)],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HotRest',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'SuperAdmin',
                    style: TextStyle(
                      color: AppTheme.brandOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final isSelected = _selectedIndex == item.pageIndex;
    // The sidebar ground is #0F172A. adminPrimary (navy) is 1.28:1 there --
    // it would disappear. brandOnDark is 7.78:1, matching the gold it
    // replaces (8.10:1).
    const accent = AppTheme.brandOnDark;
    const accentBg = Color(0x1A3FBDB4);

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
          onTap: () => _select(item.pageIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarExpanded ? 12 : 0,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: isSelected ? accentBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: accent.withOpacity(0.25), width: 1)
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
                  color: isSelected ? accent : Colors.white38,
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: accent,
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
        // Toggle collapse
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  vertical: 11,
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
                        style:
                            TextStyle(color: Colors.white24, fontSize: 12),
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
              onTap: () async {
                await ref.read(authProvider.notifier).signOut();
                if (!mounted) return;
                context.go('/login');
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _sidebarExpanded ? 12 : 0,
                  vertical: 11,
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
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
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
}
