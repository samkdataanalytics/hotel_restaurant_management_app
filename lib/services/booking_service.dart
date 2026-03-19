import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/booking.dart';
import '../models/check_in.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/expense.dart';

SupabaseClient get _db => Supabase.instance.client;

class BookingService {
  final _uuid = const Uuid();

  /// The hotel_id for the currently logged-in staff member.
  /// Set this after login via [BookingService.hotelId] = session.hotelId!
  String? hotelId;

  // ─── Row → Model mappers ───────────────────────────────────────────────────

  static Guest _guestFromRow(Map<String, dynamic> r) => Guest.fromMap({
        'id': r['id'],
        'fullName': r['full_name'],
        'email': r['email'],
        'phone': r['phone'],
        'idType': r['id_type'],
        'idNumber': r['id_number'],
        'nationality': r['nationality'],
        'passportOrNic': r['passport_or_nic'],
        'dateOfBirth': r['date_of_birth'],
        'whatsApp': r['whats_app'],
      });

  Map<String, dynamic> _guestToRow(Guest g) => {
        'id': g.id,
        'full_name': g.fullName,
        'email': g.email,
        'phone': g.phone,
        'id_type': g.idType,
        'id_number': g.idNumber,
        'nationality': g.nationality,
        'passport_or_nic': g.passportOrNic,
        'date_of_birth': g.dateOfBirth?.toIso8601String(),
        'whats_app': g.whatsApp,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static Room _roomFromRow(Map<String, dynamic> r) => Room.fromMap({
        'id': r['id'],
        'roomNumber': r['room_number'],
        'type': r['type'],
        'floor': r['floor'],
        'status': r['status'],
        'pricePerNight': r['price_per_night'],
        'maintenanceStart': r['maintenance_start'],
        'maintenanceEnd': r['maintenance_end'],
      });

  Map<String, dynamic> _roomToRow(Room r) => {
        'id': r.id,
        'room_number': r.roomNumber,
        'type': r.type.name,
        'floor': r.floor,
        'status': r.status.name,
        'price_per_night': r.pricePerNight,
        'maintenance_start': r.maintenanceStart?.toIso8601String(),
        'maintenance_end': r.maintenanceEnd?.toIso8601String(),
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static Booking _bookingFromRow(Map<String, dynamic> r) => Booking.fromMap({
        'id': r['id'],
        'bookingRef': r['booking_ref'],
        'guestId': r['guest_id'],
        'roomId': r['room_id'],
        'checkInDate': r['check_in_date'],
        'checkOutDate': r['check_out_date'],
        'status': r['status'],
        'numberOfGuests': r['number_of_guests'],
        'specialRequests': r['special_requests'] ?? '',
        'source': r['source'] ?? 'direct',
        'totalAmount': r['total_amount'],
        'isQrGenerated': r['is_qr_generated'] ?? false,
        'isQrSent': r['is_qr_sent'] ?? false,
        'isGuestFormSubmitted': r['is_guest_form_submitted'] ?? false,
        'isPaid': r['is_paid'] ?? false,
        'guestPreferences': r['guest_preferences'],
      });

  Map<String, dynamic> _bookingToRow(Booking b) => {
        'id': b.id,
        'booking_ref': b.bookingRef,
        'guest_id': b.guestId,
        'room_id': b.roomId,
        'check_in_date': b.checkInDate.toIso8601String(),
        'check_out_date': b.checkOutDate.toIso8601String(),
        'status': b.status.name,
        'number_of_guests': b.numberOfGuests,
        'special_requests': b.specialRequests,
        'source': b.source.name,
        'total_amount': b.totalAmount,
        'is_qr_generated': b.isQrGenerated,
        'is_qr_sent': b.isQrSent,
        'is_guest_form_submitted': b.isGuestFormSubmitted,
        'is_paid': b.isPaid,
        'guest_preferences': b.guestPreferences,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static CheckIn _checkInFromRow(Map<String, dynamic> r) => CheckIn.fromMap({
        'id': r['id'],
        'bookingId': r['booking_id'],
        'guestId': r['guest_id'],
        'roomId': r['room_id'],
        'checkInTime': r['check_in_time'],
        'idVerified': r['id_verified'],
        'keyIssued': r['key_issued'],
      });

  Map<String, dynamic> _checkInToRow(CheckIn c) => {
        'id': c.id,
        'booking_id': c.bookingId,
        'guest_id': c.guestId,
        'room_id': c.roomId,
        'check_in_time': c.checkInTime.toIso8601String(),
        'id_verified': c.idVerified,
        'key_issued': c.keyIssued,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  static Expense _expenseFromRow(Map<String, dynamic> r) => Expense.fromMap({
        'id': r['id'],
        'description': r['description'],
        'amount': r['amount'],
        'category': r['category'],
        'date': r['date'],
        'endDate': r['end_date'],
        'roomId': r['room_id'],
        'isBillable': r['is_billable'] ?? false,
        'isPaid': r['is_paid'] ?? false,
        'bookingId': r['booking_id'],
      });

  Map<String, dynamic> _expenseToRow(Expense e) => {
        'id': e.id,
        'description': e.description,
        'amount': e.amount,
        'category': e.category.name,
        'date': e.date.toIso8601String(),
        'end_date': e.endDate?.toIso8601String(),
        'room_id': e.roomId,
        'is_billable': e.isBillable,
        'is_paid': e.isPaid,
        'booking_id': e.bookingId,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  // ─── Booking Reference ────────────────────────────────────────────────────
  //
  // NOTE: This method is now async. Callers must await it.
  //       e.g.  final ref = await bookingService.getNextBookingRef();

  Future<String> getNextBookingRef() async {
    final rows = await _db
        .from('bookings')
        .select('booking_ref')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 'BK-0001';
    final lastRef = (rows.first['booking_ref'] as String?) ?? 'BK-0000';
    final n = int.tryParse(lastRef.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'BK-${(n + 1).toString().padLeft(4, '0')}';
  }

  // ─── Check-In Lookup ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> lookupBooking(String bookingRef) async {
    final rows = await _db
        .from('bookings')
        .select()
        .eq('booking_ref', bookingRef)
        .limit(1);
    if (rows.isEmpty) return null;

    final booking = _bookingFromRow(rows.first);

    final guestRows = await _db
        .from('guests')
        .select()
        .eq('id', booking.guestId)
        .limit(1);
    final roomRows = await _db
        .from('rooms')
        .select()
        .eq('id', booking.roomId)
        .limit(1);

    return {
      'booking': booking,
      'guest': guestRows.isNotEmpty ? _guestFromRow(guestRows.first) : null,
      'room': roomRows.isNotEmpty ? _roomFromRow(roomRows.first) : null,
    };
  }

  // ─── Check-In / Check-Out ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> performCheckIn({
    required Booking booking,
    required Guest guest,
  }) async {
    await updateGuest(guest);

    await _db
        .from('bookings')
        .update({'status': 'checkedIn'})
        .eq('id', booking.id);

    await _db
        .from('rooms')
        .update({'status': 'occupied'})
        .eq('id', booking.roomId);

    final checkIn = CheckIn(
      id: _uuid.v4(),
      bookingId: booking.id,
      guestId: guest.id,
      roomId: booking.roomId,
      checkInTime: DateTime.now(),
      idVerified: true,
      keyIssued: true,
    );
    await _db.from('check_ins').insert(_checkInToRow(checkIn));

    final updatedBooking = booking.copyWith(status: BookingStatus.checkedIn);
    final roomRows = await _db
        .from('rooms')
        .select()
        .eq('id', booking.roomId)
        .limit(1);

    return {
      'checkIn': checkIn,
      'booking': updatedBooking,
      'guest': guest,
      'room': roomRows.isNotEmpty ? _roomFromRow(roomRows.first) : null,
    };
  }

  Future<void> performCheckOut(String bookingId) async {
    final rows = await _db
        .from('bookings')
        .select('room_id')
        .eq('id', bookingId)
        .limit(1);
    if (rows.isEmpty) return;
    final roomId = rows.first['room_id'] as String;

    await _db
        .from('bookings')
        .update({'status': 'checkedOut'})
        .eq('id', bookingId);
    await _db
        .from('rooms')
        .update({'status': 'available'})
        .eq('id', roomId);
  }

  // ─── Enriched Data ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEnrichedCheckIns() async {
    final rows = await _db
        .from('check_ins')
        .select('*, bookings(*), guests(*), rooms(*)')
        .order('check_in_time', ascending: false);

    return rows.map<Map<String, dynamic>>((r) => {
          'checkIn': _checkInFromRow(r),
          'booking': r['bookings'] != null
              ? _bookingFromRow(r['bookings'] as Map<String, dynamic>)
              : null,
          'guest': r['guests'] != null
              ? _guestFromRow(r['guests'] as Map<String, dynamic>)
              : null,
          'room': r['rooms'] != null
              ? _roomFromRow(r['rooms'] as Map<String, dynamic>)
              : null,
        }).toList();
  }

  Future<List<Map<String, dynamic>>> getEnrichedBookings() async {
    final rows = await _db
        .from('bookings')
        .select('*, guests(*), rooms(*)')
        .order('created_at', ascending: false);

    return rows.map<Map<String, dynamic>>((r) => {
          'booking': _bookingFromRow(r),
          'guest': r['guests'] != null
              ? _guestFromRow(r['guests'] as Map<String, dynamic>)
              : null,
          'room': r['rooms'] != null
              ? _roomFromRow(r['rooms'] as Map<String, dynamic>)
              : null,
        }).toList();
  }

  // ─── Dashboard Stats ──────────────────────────────────────────────────────

  Future<Map<String, int>> getDashboardStats() async {
    final todayStart = DateTime.now();
    final startOfDay = DateTime(todayStart.year, todayStart.month, todayStart.day)
        .toIso8601String();
    final endOfDay = DateTime(todayStart.year, todayStart.month, todayStart.day, 23, 59, 59)
        .toIso8601String();

    final results = await Future.wait([
      // Today's check-ins
      _db.from('check_ins').select('id')
          .gte('check_in_time', startOfDay)
          .lte('check_in_time', endOfDay),
      // Occupied rooms
      _db.from('rooms').select('id').eq('status', 'occupied'),
      // Available rooms
      _db.from('rooms').select('id').eq('status', 'available'),
      // Pending arrivals
      _db.from('bookings').select('id').eq('status', 'pending'),
    ]);

    return {
      'todayCheckIns': results[0].length,
      'occupiedRooms': results[1].length,
      'availableRooms': results[2].length,
      'pendingArrivals': results[3].length,
    };
  }

  // ─── Rooms ────────────────────────────────────────────────────────────────

  Future<List<Room>> getAllRooms() async {
    final rows = await _db.from('rooms').select().order('room_number');
    return rows.map(_roomFromRow).toList();
  }

  Future<Room> toggleRoomStatus(Room room) async {
    final newStatus = room.status == RoomStatus.available
        ? RoomStatus.maintenance
        : room.status == RoomStatus.maintenance
            ? RoomStatus.available
            : RoomStatus.occupied;
    final updated = room.copyWith(status: newStatus);
    await _db
        .from('rooms')
        .update({'status': newStatus.name})
        .eq('id', room.id);
    return updated;
  }

  Future<void> addRoom(Room room) async {
    await _db.from('rooms').insert(_roomToRow(room));
  }

  Future<void> updateRoom(Room room) async {
    await _db.from('rooms').update(_roomToRow(room)).eq('id', room.id);
  }

  Future<void> deleteRoom(String roomId) async {
    await _db.from('rooms').delete().eq('id', roomId);
  }

  // ─── Reservations ─────────────────────────────────────────────────────────

  Future<void> addReservation(Booking booking) async {
    await _db.from('bookings').insert(_bookingToRow(booking));
    await _syncBookingEffects(booking);
  }

  Future<void> updateBooking(Booking booking) async {
    await _db
        .from('bookings')
        .update(_bookingToRow(booking))
        .eq('id', booking.id);
    await _syncBookingEffects(booking);
  }

  Future<void> deleteReservation(String bookingId) async {
    await _db.from('bookings').delete().eq('id', bookingId);
  }

  /// Syncs room status and check_in record whenever a booking is saved.
  ///
  /// - checkedIn  → room occupied  + ensure a check_in record exists
  /// - checkedOut → room available
  /// - pending / cancelled → room available
  Future<void> _syncBookingEffects(Booking booking) async {
    final roomStatus = booking.status == BookingStatus.checkedIn
        ? 'occupied'
        : 'available';

    await _db
        .from('rooms')
        .update({'status': roomStatus})
        .eq('id', booking.roomId);

    if (booking.status == BookingStatus.checkedIn) {
      final existing = await _db
          .from('check_ins')
          .select('id')
          .eq('booking_id', booking.id)
          .limit(1);

      if (existing.isEmpty) {
        final checkIn = CheckIn(
          id: _uuid.v4(),
          bookingId: booking.id,
          guestId: booking.guestId,
          roomId: booking.roomId,
          checkInTime: DateTime.now(),
          idVerified: true,
          keyIssued: true,
        );
        await _db.from('check_ins').insert(_checkInToRow(checkIn));
      }
    }
  }

  // ─── Guests ───────────────────────────────────────────────────────────────

  Future<List<Guest>> getAllGuests() async {
    final rows = await _db.from('guests').select().order('full_name');
    return rows.map(_guestFromRow).toList();
  }

  Future<void> addGuest(Guest guest) async {
    await _db.from('guests').insert(_guestToRow(guest));
  }

  Future<void> updateGuest(Guest guest) async {
    await _db.from('guests').upsert(_guestToRow(guest));
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    final rows = await _db
        .from('expenses')
        .select()
        .order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<List<Expense>> getRoomExpenses(String roomId) async {
    final rows = await _db
        .from('expenses')
        .select()
        .eq('room_id', roomId)
        .order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<List<Expense>> getExpensesByBookingId(String bookingId) async {
    final rows = await _db
        .from('expenses')
        .select()
        .eq('booking_id', bookingId)
        .order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.from('expenses').insert(_expenseToRow(expense));
  }

  Future<void> updateExpense(Expense expense) async {
    await _db
        .from('expenses')
        .update(_expenseToRow(expense))
        .eq('id', expense.id);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.from('expenses').delete().eq('id', expenseId);
  }
}
