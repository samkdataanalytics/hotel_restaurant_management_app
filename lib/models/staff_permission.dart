import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Providers (synced by AppShell on every property switch) ─────────────────

/// True when the active user is a manager/owner — they always have full access.
final isPropertyManagerProvider = StateProvider<bool>((ref) => true);

/// Per-section privilege map for the current non-manager user.
final activeSectionPermissionsProvider =
    StateProvider<Map<String, PrivilegeLevel>>((ref) => {});

/// Returns true if the current user may create/edit/delete in [sectionKey].
bool canEditSection(WidgetRef ref, String sectionKey) {
  if (ref.watch(isPropertyManagerProvider)) return true;
  final perms = ref.watch(activeSectionPermissionsProvider);
  return (perms[sectionKey] ?? PrivilegeLevel.none) == PrivilegeLevel.edit;
}

// ─── Section keys (maps to page indices in AppShell) ─────────────────────────

const Map<int, String> kSectionKeyByPageIndex = {
  0:  'hotel_dashboard',
  1:  'hotel_checkins',
  2:  'hotel_rooms',
  3:  'hotel_reservations',
  4:  'hotel_financials',
  5:  'hotel_expenses',
  6:  'restaurant_pos',
  7:  'restaurant_tables',
  8:  'restaurant_kitchen',
  9:  'restaurant_management',
  10: 'restaurant_orders',
  11: 'restaurant_analytics',
  12: 'restaurant_cancellations',
};

const Map<String, String> kSectionLabel = {
  'hotel_dashboard':          'Dashboard',
  'hotel_checkins':           'Check-Ins',
  'hotel_rooms':              'Rooms',
  'hotel_reservations':       'Reservations',
  'hotel_financials':         'Financials',
  'hotel_expenses':           'Expenses',
  'restaurant_pos':           'POS',
  'restaurant_tables':        'Tables',
  'restaurant_kitchen':       'Kitchen',
  'restaurant_management':    'Restaurant',
  'restaurant_orders':        'Orders',
  'restaurant_analytics':     'Analytics',
  'restaurant_cancellations': 'Cancellations',
};

const List<String> kHotelSectionKeys = [
  'hotel_dashboard',
  'hotel_checkins',
  'hotel_rooms',
  'hotel_reservations',
  'hotel_financials',
  'hotel_expenses',
];

const List<String> kRestaurantSectionKeys = [
  'restaurant_pos',
  'restaurant_tables',
  'restaurant_kitchen',
  'restaurant_management',
  'restaurant_orders',
  'restaurant_analytics',
  'restaurant_cancellations',
];

// ─── Privilege level ──────────────────────────────────────────────────────────

enum PrivilegeLevel { none, view, edit }

PrivilegeLevel parsePrivilege(String? raw) {
  switch (raw) {
    case 'view': return PrivilegeLevel.view;
    case 'edit': return PrivilegeLevel.edit;
    default:     return PrivilegeLevel.none;
  }
}

extension PrivilegeLevelX on PrivilegeLevel {
  String get value {
    switch (this) {
      case PrivilegeLevel.none: return 'none';
      case PrivilegeLevel.view: return 'view';
      case PrivilegeLevel.edit: return 'edit';
    }
  }

  String get label {
    switch (this) {
      case PrivilegeLevel.none: return 'None';
      case PrivilegeLevel.view: return 'View';
      case PrivilegeLevel.edit: return 'Edit';
    }
  }
}

// ─── Staff member model ───────────────────────────────────────────────────────

class PropertyStaffMember {
  final String userId;
  final String fullName;
  final String email;
  final String role; // 'manager' | 'staff'
  final Map<String, PrivilegeLevel> permissions;

  const PropertyStaffMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.permissions,
  });

  bool get isManager => role == 'manager';

  int get accessCount =>
      permissions.values.where((p) => p != PrivilegeLevel.none).length;

  int get editCount =>
      permissions.values.where((p) => p == PrivilegeLevel.edit).length;

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty || fullName.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
