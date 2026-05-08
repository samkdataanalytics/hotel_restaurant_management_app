// ─── Shift status ─────────────────────────────────────────────────────────────

enum ShiftStatus { scheduled, completed, cancelled }

ShiftStatus _parseStatus(String? s) {
  switch (s) {
    case 'completed':  return ShiftStatus.completed;
    case 'cancelled':  return ShiftStatus.cancelled;
    default:           return ShiftStatus.scheduled;
  }
}

// ─── StaffShift ───────────────────────────────────────────────────────────────

class StaffShift {
  final String id;
  final String hotelId;
  final String staffUserId;
  final String staffName;
  final DateTime shiftDate;
  final String startTime; // 'HH:mm'
  final String endTime;   // 'HH:mm'
  final String role;
  final String notes;
  final ShiftStatus status;
  final DateTime createdAt;

  const StaffShift({
    required this.id,
    required this.hotelId,
    required this.staffUserId,
    required this.staffName,
    required this.shiftDate,
    required this.startTime,
    required this.endTime,
    required this.role,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  factory StaffShift.fromMap(Map<String, dynamic> r) => StaffShift(
        id:           r['id'] as String,
        hotelId:      r['hotel_id'] as String,
        staffUserId:  r['staff_user_id'] as String,
        staffName:    r['staff_name'] as String? ?? '',
        shiftDate:    DateTime.parse(r['shift_date'] as String),
        startTime:    r['start_time'] as String,
        endTime:      r['end_time'] as String,
        role:         r['role'] as String? ?? 'staff',
        notes:        r['notes'] as String? ?? '',
        status:       _parseStatus(r['status'] as String?),
        createdAt:    DateTime.parse(r['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':            id,
        'hotel_id':      hotelId,
        'staff_user_id': staffUserId,
        'staff_name':    staffName,
        'shift_date':    shiftDate.toIso8601String().substring(0, 10),
        'start_time':    startTime,
        'end_time':      endTime,
        'role':          role,
        'notes':         notes,
        'status':        status.name,
      };

  StaffShift copyWith({
    String? staffName,
    DateTime? shiftDate,
    String? startTime,
    String? endTime,
    String? role,
    String? notes,
    ShiftStatus? status,
  }) =>
      StaffShift(
        id:           id,
        hotelId:      hotelId,
        staffUserId:  staffUserId,
        staffName:    staffName ?? this.staffName,
        shiftDate:    shiftDate ?? this.shiftDate,
        startTime:    startTime ?? this.startTime,
        endTime:      endTime ?? this.endTime,
        role:         role ?? this.role,
        notes:        notes ?? this.notes,
        status:       status ?? this.status,
        createdAt:    createdAt,
      );

  /// Duration in minutes between startTime and endTime (same calendar day).
  int get durationMinutes {
    final s = _parseMins(startTime);
    final e = _parseMins(endTime);
    return e >= s ? e - s : (24 * 60 - s) + e; // handle overnight shifts
  }

  String get durationLabel {
    final m = durationMinutes;
    final h = m ~/ 60;
    final rem = m % 60;
    if (h == 0) return '${rem}m';
    if (rem == 0) return '${h}h';
    return '${h}h ${rem}m';
  }

  static int _parseMins(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

// ─── TimeRecord ───────────────────────────────────────────────────────────────

class TimeRecord {
  final String id;
  final String hotelId;
  final String staffUserId;
  final String staffName;
  final String? shiftId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String notes;
  final DateTime createdAt;

  const TimeRecord({
    required this.id,
    required this.hotelId,
    required this.staffUserId,
    required this.staffName,
    this.shiftId,
    required this.clockIn,
    this.clockOut,
    required this.notes,
    required this.createdAt,
  });

  factory TimeRecord.fromMap(Map<String, dynamic> r) => TimeRecord(
        id:           r['id'] as String,
        hotelId:      r['hotel_id'] as String,
        staffUserId:  r['staff_user_id'] as String,
        staffName:    r['staff_name'] as String? ?? '',
        shiftId:      r['shift_id'] as String?,
        clockIn:      DateTime.parse(r['clock_in'] as String).toLocal(),
        clockOut:     r['clock_out'] != null
            ? DateTime.parse(r['clock_out'] as String).toLocal()
            : null,
        notes:        r['notes'] as String? ?? '',
        createdAt:    DateTime.parse(r['created_at'] as String),
      );

  bool get isActive => clockOut == null;

  /// Total worked duration, or null if still clocked in.
  Duration? get duration =>
      clockOut?.difference(clockIn);

  String get durationLabel {
    final d = duration;
    if (d == null) return 'Active';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
