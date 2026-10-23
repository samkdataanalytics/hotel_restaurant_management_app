enum RoomType { standard, deluxe, suite }

enum RoomStatus { available, occupied, maintenance }

/// Cleaning state, tracked separately from occupancy in [RoomStatus].
///
/// The two are genuinely independent: a room can be occupied and dirty, or
/// available and awaiting inspection. Folding them into one column loses the
/// information a housekeeping round is built on.
enum HousekeepingStatus { ready, dirty, cleaning, inspected }

class Room {
  final String id;
  final String roomNumber;
  final RoomType type;
  final int floor;
  final RoomStatus status;
  final double pricePerNight;
  final DateTime? maintenanceStart;
  final DateTime? maintenanceEnd;

  /// Defaults to ready so rows written before this column existed, and any
  /// caller that does not set it, behave exactly as they did before.
  final HousekeepingStatus housekeeping;

  Room({
    required this.id,
    required this.roomNumber,
    required this.type,
    required this.floor,
    required this.status,
    required this.pricePerNight,
    this.maintenanceStart,
    this.maintenanceEnd,
    this.housekeeping = HousekeepingStatus.ready,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomNumber': roomNumber,
      'type': type.name,
      'floor': floor,
      'status': status.name,
      'pricePerNight': pricePerNight,
      'maintenanceStart': maintenanceStart?.toIso8601String(),
      'maintenanceEnd': maintenanceEnd?.toIso8601String(),
      'housekeeping': housekeeping.name,
    };
  }

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as String,
      roomNumber: map['roomNumber'] as String,
      type: RoomType.values.firstWhere((e) => e.name == map['type']),
      floor: map['floor'] as int,
      status: RoomStatus.values.firstWhere((e) => e.name == map['status']),
      pricePerNight: (map['pricePerNight'] as num).toDouble(),
      maintenanceStart: map['maintenanceStart'] != null
          ? DateTime.parse(map['maintenanceStart'] as String)
          : null,
      maintenanceEnd: map['maintenanceEnd'] != null
          ? DateTime.parse(map['maintenanceEnd'] as String)
          : null,
      // orElse rather than a bare firstWhere: an unrecognised value must not
      // throw and take the whole room list down with it.
      housekeeping: HousekeepingStatus.values.firstWhere(
        (e) => e.name == map['housekeeping'],
        orElse: () => HousekeepingStatus.ready,
      ),
    );
  }

  static Room fromDbRow(Map<String, dynamic> r) => Room.fromMap({
        'id': r['id'],
        'roomNumber': r['room_number'],
        'type': r['type'],
        'floor': r['floor'],
        'status': r['status'],
        'pricePerNight': r['price_per_night'],
        'maintenanceStart': r['maintenance_start'],
        'maintenanceEnd': r['maintenance_end'],
      });

  Room copyWith({
    String? id,
    String? roomNumber,
    RoomType? type,
    int? floor,
    RoomStatus? status,
    double? pricePerNight,
    DateTime? maintenanceStart,
    DateTime? maintenanceEnd,
    bool clearMaintenance = false,
    HousekeepingStatus? housekeeping,
  }) {
    return Room(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      type: type ?? this.type,
      floor: floor ?? this.floor,
      status: status ?? this.status,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      maintenanceStart: clearMaintenance ? null : (maintenanceStart ?? this.maintenanceStart),
      maintenanceEnd: clearMaintenance ? null : (maintenanceEnd ?? this.maintenanceEnd),
      housekeeping: housekeeping ?? this.housekeeping,
    );
  }

  /// Check if this room is under maintenance on a specific day
  bool isUnderMaintenanceOn(DateTime day) {
    if (maintenanceStart == null || maintenanceEnd == null) {
      return status == RoomStatus.maintenance;
    }
    final dayStart = DateTime(day.year, day.month, day.day);
    final mStart = DateTime(maintenanceStart!.year, maintenanceStart!.month, maintenanceStart!.day);
    final mEnd = DateTime(maintenanceEnd!.year, maintenanceEnd!.month, maintenanceEnd!.day)
        .add(const Duration(days: 1));
    return !dayStart.isBefore(mStart) && dayStart.isBefore(mEnd);
  }

  /// Check if maintenance overlaps with a date range
  bool maintenanceOverlapsWith(DateTime start, DateTime end) {
    if (maintenanceStart == null || maintenanceEnd == null) {
      return status == RoomStatus.maintenance;
    }
    final mStart = DateTime(maintenanceStart!.year, maintenanceStart!.month, maintenanceStart!.day);
    final mEnd = DateTime(maintenanceEnd!.year, maintenanceEnd!.month, maintenanceEnd!.day)
        .add(const Duration(days: 1));
    final rStart = DateTime(start.year, start.month, start.day);
    final rEnd = DateTime(end.year, end.month, end.day);
    return rStart.isBefore(mEnd) && rEnd.isAfter(mStart);
  }

  String get typeLabel {
    switch (type) {
      case RoomType.standard:
        return 'Standard';
      case RoomType.deluxe:
        return 'Deluxe';
      case RoomType.suite:
        return 'Suite';
    }
  }

  String get housekeepingLabel {
    switch (housekeeping) {
      case HousekeepingStatus.ready:
        return 'Ready';
      case HousekeepingStatus.dirty:
        return 'Dirty';
      case HousekeepingStatus.cleaning:
        return 'Cleaning';
      case HousekeepingStatus.inspected:
        return 'Inspected';
    }
  }

  String get statusLabel {
    switch (status) {
      case RoomStatus.available:
        return 'Available';
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.maintenance:
        return 'Maintenance';
    }
  }
}
