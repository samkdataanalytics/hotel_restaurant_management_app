import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/staff_shift.dart';
import '../../providers/service_providers.dart';
import '../../services/notification_service.dart';
import '../../services/shift_service.dart';
import '../session/staff_session.dart';

const _uuid = Uuid();

/// Today's numbers, as one figure set.
class TodayStats {
  final int checkInsToday;
  final int occupiedRooms;
  final int availableRooms;
  final int pendingArrivals;
  final int totalRooms;
  final int activeKitchenOrders;

  const TodayStats({
    this.checkInsToday = 0,
    this.occupiedRooms = 0,
    this.availableRooms = 0,
    this.pendingArrivals = 0,
    this.totalRooms = 0,
    this.activeKitchenOrders = 0,
  });

  /// 0.0–1.0. Rooms under maintenance count against capacity, because a room
  /// that cannot be sold is not occupancy the owner earns from.
  double get occupancy =>
      totalRooms == 0 ? 0 : (occupiedRooms / totalRooms).clamp(0.0, 1.0);
}

/// Reads behind the manager surfaces.
///
/// `ShiftService` and `NotificationService` take their tenant in the
/// constructor rather than a mutable field, so unlike the restaurant and
/// booking services they are built per property here rather than scoped through
/// `applyPropertyScope`.
class ManagerRepository {
  final Ref _ref;
  ManagerRepository(this._ref);

  String? get _propertyId =>
      _ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;

  ShiftService? get _shifts {
    final id = _propertyId;
    return id == null ? null : ShiftService(id);
  }

  NotificationService? get _notifications {
    final id = _propertyId;
    return id == null ? null : NotificationService(id);
  }

  Future<TodayStats> loadTodayStats() async {
    final booking = _ref.read(bookingServiceProvider);
    final restaurant = _ref.read(restaurantServiceProvider);

    // Independent reads — serialising them would make the first screen an
    // owner opens the slowest one.
    final results = await (
      booking.getDashboardStats(),
      restaurant.countActiveKitchenOrdersToday(),
    ).wait;

    final stats = results.$1;
    return TodayStats(
      checkInsToday: stats['todayCheckIns'] ?? 0,
      occupiedRooms: stats['occupiedRooms'] ?? 0,
      availableRooms: stats['availableRooms'] ?? 0,
      pendingArrivals: stats['pendingArrivals'] ?? 0,
      totalRooms: stats['totalRooms'] ?? 0,
      activeKitchenOrders: results.$2,
    );
  }

  // ─── Time clock ───────────────────────────────────────────────────────────

  /// The caller's open clock-in, if they are on shift.
  Future<TimeRecord?> activeTimeRecord() async =>
      _shifts?.getMyActiveRecord();

  Future<TimeRecord?> clockIn({String staffName = ''}) async =>
      _shifts?.clockIn(staffName: staffName);

  Future<void> clockOut(String recordId, {String notes = ''}) async =>
      _shifts?.clockOut(recordId, notes: notes);

  /// This week's shifts for the signed-in user only.
  ///
  /// The rota for everyone is a manager view and a tablet-sized problem; what a
  /// staff member opens their phone for is their own week.
  Future<List<StaffShift>> myShiftsThisWeek(String userId) async {
    final service = _shifts;
    if (service == null) return [];
    final now = DateTime.now();
    final start = ShiftService.weekStart(now);
    final shifts = await service.getShiftsForRange(
      start,
      start.add(const Duration(days: 6)),
    );
    return shifts.where((s) => s.staffUserId == userId).toList();
  }

  /// The caller's own clock-ins over the past [days].
  Future<List<TimeRecord>> myRecentTimeRecords(
    String userId, {
    int days = 14,
  }) async {
    final service = _shifts;
    if (service == null) return [];
    final now = DateTime.now();
    final records = await service.getTimeRecords(
      from: now.subtract(Duration(days: days)),
      to: now,
      staffUserId: userId,
    );
    records.sort((a, b) => b.clockIn.compareTo(a.clockIn));
    return records;
  }

  /// Every shift in the week containing [anyDay], for the whole property.
  Future<List<StaffShift>> shiftsForWeek(DateTime anyDay) async {
    final service = _shifts;
    if (service == null) return [];
    final start = ShiftService.weekStart(anyDay);
    return service.getShiftsForRange(start, start.add(const Duration(days: 6)));
  }

  Future<void> addShift(StaffShift shift) async => _shifts?.addShift(shift);

  Future<void> deleteShift(String shiftId) async =>
      _shifts?.deleteShift(shiftId);

  /// Copies one week's rota onto the next.
  ///
  /// The roadmap calls this the shortcut that makes scheduling bearable, and it
  /// is: most weeks are last week with a couple of changes. Shifts already on
  /// the target week are left alone rather than duplicated — running it twice
  /// must not double-book everyone.
  Future<int> copyWeek({
    required DateTime fromWeek,
    required DateTime toWeek,
  }) async {
    final service = _shifts;
    final propertyId = _propertyId;
    if (service == null || propertyId == null) return 0;

    final source = await shiftsForWeek(fromWeek);
    if (source.isEmpty) return 0;

    final existing = await shiftsForWeek(toWeek);
    String key(String userId, int weekday, String start) =>
        '$userId|$weekday|$start';
    final taken = {
      for (final s in existing)
        key(s.staffUserId, s.shiftDate.weekday, s.startTime),
    };

    final offset = ShiftService.weekStart(toWeek)
        .difference(ShiftService.weekStart(fromWeek));

    var copied = 0;
    for (final shift in source) {
      if (shift.status == ShiftStatus.cancelled) continue;
      final date = shift.shiftDate.add(offset);
      if (taken.contains(key(shift.staffUserId, date.weekday, shift.startTime))) {
        continue;
      }

      await service.addShift(StaffShift(
        id: _uuid.v4(),
        hotelId: propertyId,
        staffUserId: shift.staffUserId,
        staffName: shift.staffName,
        shiftDate: date,
        startTime: shift.startTime,
        endTime: shift.endTime,
        role: shift.role,
        notes: shift.notes,
        status: ShiftStatus.scheduled,
        createdAt: DateTime.now(),
      ));
      copied++;
    }
    return copied;
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Future<List<AppNotification>> loadNotifications() async =>
      await _notifications?.getNotifications() ?? const [];

  Future<void> markNotificationRead(String id) async =>
      _notifications?.markAsRead(id);

  Future<void> markAllNotificationsRead() async =>
      _notifications?.markAllAsRead();
}

final managerRepositoryProvider = Provider<ManagerRepository>(
  ManagerRepository.new,
);
