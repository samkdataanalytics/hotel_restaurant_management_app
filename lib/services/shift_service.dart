import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/staff_shift.dart';

class ShiftService {
  final _db = Supabase.instance.client;
  final String hotelId;

  ShiftService(this.hotelId);

  String? get _currentUserId => _db.auth.currentUser?.id;

  // ── Shifts ────────────────────────────────────────────────────────────────

  /// Returns all shifts for the hotel within [from]..[to] (inclusive dates).
  Future<List<StaffShift>> getShiftsForRange(
      DateTime from, DateTime to) async {
    final rows = await _db
        .from('staff_shifts')
        .select()
        .eq('hotel_id', hotelId)
        .gte('shift_date', from.toIso8601String().substring(0, 10))
        .lte('shift_date', to.toIso8601String().substring(0, 10))
        .order('shift_date')
        .order('start_time');
    return rows.map<StaffShift>(StaffShift.fromMap).toList();
  }

  Future<void> addShift(StaffShift shift) async {
    await _db.from('staff_shifts').insert(shift.toMap());
  }

  Future<void> updateShift(StaffShift shift) async {
    await _db
        .from('staff_shifts')
        .update(shift.toMap())
        .eq('id', shift.id);
  }

  Future<void> deleteShift(String shiftId) async {
    await _db.from('staff_shifts').delete().eq('id', shiftId);
  }

  // ── Time Records ──────────────────────────────────────────────────────────

  /// Returns time records for the hotel within [from]..[to] clock_in range.
  /// Pass [staffUserId] to filter to a single staff member.
  Future<List<TimeRecord>> getTimeRecords({
    required DateTime from,
    required DateTime to,
    String? staffUserId,
  }) async {
    var query = _db
        .from('staff_time_records')
        .select()
        .eq('hotel_id', hotelId)
        .gte('clock_in', from.toIso8601String())
        .lte('clock_in', to.toIso8601String());

    if (staffUserId != null) {
      query = query.eq('staff_user_id', staffUserId);
    }

    final rows = await query.order('clock_in', ascending: false);
    return rows.map<TimeRecord>(TimeRecord.fromMap).toList();
  }

  /// Returns an active (no clock_out) record for the current user, or null.
  Future<TimeRecord?> getMyActiveRecord() async {
    final uid = _currentUserId;
    if (uid == null) return null;
    final rows = await _db
        .from('staff_time_records')
        .select()
        .eq('hotel_id', hotelId)
        .eq('staff_user_id', uid)
        .isFilter('clock_out', null)
        .order('clock_in', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return TimeRecord.fromMap(rows.first);
  }

  /// Clocks the current user in. Optionally links to a [shiftId].
  Future<TimeRecord> clockIn({String staffName = '', String? shiftId}) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final row = {
      'hotel_id':       hotelId,
      'staff_user_id':  uid,
      'staff_name':     staffName,
      'clock_in':       DateTime.now().toUtc().toIso8601String(),
      if (shiftId != null) 'shift_id': shiftId,
    };
    final result = await _db
        .from('staff_time_records')
        .insert(row)
        .select()
        .single();
    return TimeRecord.fromMap(result);
  }

  /// Clocks out an existing time record by [recordId].
  Future<void> clockOut(String recordId, {String notes = ''}) async {
    await _db.from('staff_time_records').update({
      'clock_out': DateTime.now().toUtc().toIso8601String(),
      if (notes.isNotEmpty) 'notes': notes,
    }).eq('id', recordId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Start of ISO week (Monday) that contains [date].
  static DateTime weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// The 7 days of the week that contains [date].
  static List<DateTime> weekDays(DateTime date) {
    final start = weekStart(date);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }
}
