import 'package:flutter/material.dart';

import '../../session/staff_session.dart';
import '../frontdesk/arrivals_screen.dart';
import '../manager/today_screen.dart';
import '../frontdesk/rooms_screen.dart';
import '../orders/orders_screen.dart';
import '../tables/table_floor_screen.dart';

/// One bottom-nav destination.
class StaffTab {
  /// The permission section key this tab requires, or null when the tab is
  /// always available (the "More" tab).
  final String? sectionKey;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;

  const StaffTab({
    required this.sectionKey,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.build,
  });
}

/// Every tab the staff app can show, in display order.
///
/// Five at most, which is what a bottom bar carries before the labels stop
/// being readable — and exactly what an owner with every permission sees. Once-
/// a-day actions (clocking in, logging an expense, the kitchen board) live in
/// the app bar menu instead, because a tab is for a surface you work from, not
/// a thing you do and leave.
const _allTabs = <StaffTab>[
  StaffTab(
    sectionKey: 'hotel_dashboard',
    label: 'Today',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    build: TodayScreen.new,
  ),
  StaffTab(
    sectionKey: 'restaurant_tables',
    label: 'Floor',
    icon: Icons.table_restaurant_outlined,
    selectedIcon: Icons.table_restaurant,
    build: TableFloorScreen.new,
  ),
  StaffTab(
    sectionKey: 'restaurant_orders',
    label: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    build: OrdersScreen.new,
  ),
  StaffTab(
    sectionKey: 'hotel_checkins',
    label: 'Arrivals',
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg,
    build: ArrivalsScreen.new,
  ),
  StaffTab(
    sectionKey: 'hotel_rooms',
    label: 'Rooms',
    icon: Icons.meeting_room_outlined,
    selectedIcon: Icons.meeting_room,
    build: RoomsScreen.new,
  ),
];

/// The tabs this user can actually see, built from their privilege map.
///
/// Never a fixed list: a waiter with only POS and Tables access gets two tabs
/// and lands on the floor, rather than an empty hotel dashboard they have no
/// permission to load.
///
/// Managers and owners bypass the section map (`canView` returns true for
/// everything), matching how `create_staff_member` skips writing permission
/// rows for them.
/// Returns an empty list when the user has no permitted section at all. The
/// shell renders a dedicated explanation for that rather than an empty tab bar;
/// property switching and sign-out live in the app bar menu, so they stay
/// reachable either way.
List<StaffTab> visibleTabsFor(StaffSessionState session) {
  assert(_allTabs.length <= 5,
      'A bottom bar past five destinations truncates its labels. Put the '
      'extra surface in the app bar menu instead.');
  return _allTabs
      .where((t) => t.sectionKey == null || session.canView(t.sectionKey!))
      .toList();
}

/// Whether this user may create or modify orders.
///
/// Order entry writes are gated on the POS section specifically, not on having
/// the Floor tab: `restaurant_tables` at `view` is a legitimate read-only
/// configuration — a runner who can see table state but not take orders.
bool canTakeOrders(StaffSessionState session) =>
    session.canEdit('restaurant_pos');
