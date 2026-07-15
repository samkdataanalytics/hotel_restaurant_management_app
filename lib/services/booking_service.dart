import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/booking.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/guest.dart';
import '../domain/entities/room.dart';
import '../domain/entities/expense.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/repositories/room_repository.dart';
import '../domain/repositories/guest_repository.dart';
import '../domain/repositories/check_in_repository.dart';
import '../domain/repositories/expense_repository.dart';
import '../di/injection_container.dart';
import '../domain/usecases/get_dashboard_stats.dart';
import 'notification_service.dart';

SupabaseClient get _db => Supabase.instance.client;

class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final _bookingRepo = sl<BookingRepository>();
  final _roomRepo = sl<RoomRepository>();
  final _guestRepo = sl<GuestRepository>();
  final _checkInRepo = sl<CheckInRepository>();
  final _expenseRepo = sl<ExpenseRepository>();

  final _uuid = const Uuid();

  /// The hotel_id for the currently active property.
  /// Set via AppShell._applyActiveProperty() when the active property changes.
  String? hotelId;

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

  // ─── Booking Reference ────────────────────────────────────────────────────
  //
  // NOTE: This method is now async. Callers must await it.
  //       e.g.  final ref = await bookingService.getNextBookingRef();

  Future<String> getNextBookingRef() async {
    return _bookingRepo.getNextBookingRef();
  }

  // ─── Check-In Lookup ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> lookupBooking(String bookingRef) async {
    final response = await _db.rpc(
      'lookup_guest_booking',
      params: {'p_booking_ref': bookingRef},
    );
    if (response == null) return null;

    final r = response as Map<String, dynamic>;
    return {
      'booking': Booking.fromDbRow(r['booking'] as Map<String, dynamic>),
      'guest':   r['guest'] != null ? Guest.fromDbRow(r['guest'] as Map<String, dynamic>) : null,
      'room':    r['room']  != null ? Room.fromDbRow(r['room']  as Map<String, dynamic>) : null,
      'hotelId': r['hotel_id'] as String? ?? '',
    };
  }

  Future<void> submitGuestForm({
    required String bookingRef,
    required Guest guest,
    required Map<String, dynamic> preferences,
    String specialRequests = '',
  }) async {
    await _db.rpc('submit_guest_form', params: {
      'p_booking_ref':       bookingRef,
      'p_full_name':         guest.fullName,
      'p_email':             guest.email,
      'p_phone':             guest.phone,
      'p_id_type':           guest.idType,
      'p_id_number':         guest.idNumber,
      'p_nationality':       guest.nationality,
      'p_passport_or_nic':   guest.passportOrNic,
      'p_date_of_birth':     guest.dateOfBirth?.toIso8601String(),
      'p_whats_app':         guest.whatsApp,
      'p_guest_preferences': preferences,
      'p_special_requests':  specialRequests,
    });
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

    final room =
        roomRows.isNotEmpty ? Room.fromDbRow(roomRows.first) : null;

    // Fire check-in notification (non-blocking)
    if (hotelId != null && room != null) {
      NotificationService(hotelId!).notifyCheckIn(
        guestName: guest.fullName,
        roomNumber: room.roomNumber,
        bookingRef: booking.bookingRef,
      );
    }

    return {
      'checkIn': checkIn,
      'booking': updatedBooking,
      'guest': guest,
      'room': room,
    };
  }

  Future<void> performCheckOut(String bookingId) async {
    final rows = await _db
        .from('bookings')
        .select('room_id, booking_ref, guest_id')
        .eq('id', bookingId)
        .limit(1);
    if (rows.isEmpty) return;
    final roomId = rows.first['room_id'] as String;
    final bookingRef = rows.first['booking_ref'] as String? ?? '';
    final guestId = rows.first['guest_id'] as String? ?? '';

    await _db
        .from('bookings')
        .update({'status': 'checkedOut'})
        .eq('id', bookingId);
    await _db
        .from('rooms')
        .update({'status': 'available'})
        .eq('id', roomId);

    // Fire check-out notification (non-blocking)
    if (hotelId != null) {
      _fireCheckOutNotification(
          roomId: roomId, guestId: guestId, bookingRef: bookingRef);
    }
  }

  Future<void> _fireCheckOutNotification({
    required String roomId,
    required String guestId,
    required String bookingRef,
  }) async {
    try {
      final results = await Future.wait([
        _db.from('guests').select('full_name').eq('id', guestId).limit(1),
        _db.from('rooms').select('room_number').eq('id', roomId).limit(1),
      ]);
      final guestName = (results[0] as List).isNotEmpty
          ? (results[0] as List).first['full_name'] as String
          : 'Guest';
      final roomNumber = (results[1] as List).isNotEmpty
          ? (results[1] as List).first['room_number'] as String
          : '—';
      await NotificationService(hotelId!).notifyCheckOut(
        guestName: guestName,
        roomNumber: roomNumber,
        bookingRef: bookingRef,
      );
    } catch (_) {}
  }

  // ─── Enriched Data ────────────────────────────────────────────────────────

  /// Returns only ACTIVE (currently in-house) check-ins — guests whose booking
  /// status is still 'checkedIn'. Checked-out and orphaned records are excluded.
  Future<List<Map<String, dynamic>>> getEnrichedCheckIns() async {
    return _checkInRepo.getEnrichedCheckIns();
  }

  Future<List<Map<String, dynamic>>> getEnrichedBookings() async {
    return _bookingRepo.getEnrichedBookings();
  }

  // ─── Badge counts (lightweight — IDs only, server-filtered) ─────────────

  /// Returns the number of pending bookings arriving today.
  /// Used by AppShell badge; fetches only IDs, no joins.
  Future<int> countPendingArrivalsToday() async {
    return _bookingRepo.countPendingArrivalsToday();
  }

  // ─── Dashboard Stats ──────────────────────────────────────────────────────

  Future<Map<String, int>> getDashboardStats() async {
    return sl<GetDashboardStats>()();
  }

  // ─── Rooms ────────────────────────────────────────────────────────────────

  Future<List<Room>> getAllRooms() async {
    return _roomRepo.getAllRooms();
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
    await _roomRepo.addRoom(room);
  }

  Future<void> updateRoom(Room room) async {
    await _roomRepo.updateRoom(room);
  }

  Future<void> deleteRoom(String roomId) async {
    await _roomRepo.deleteRoom(roomId);
  }

  // ─── Reservations ─────────────────────────────────────────────────────────

  Future<void> addReservation(Booking booking) async {
    await _bookingRepo.addBooking(booking);
    await _syncBookingEffects(booking);
    _fireReservationNotification(booking); // non-blocking
  }

  Future<void> _fireReservationNotification(Booking booking) async {
    if (hotelId == null) return;
    try {
      final results = await Future.wait([
        _db.from('guests').select('full_name').eq('id', booking.guestId).limit(1),
        _db.from('rooms').select('room_number').eq('id', booking.roomId).limit(1),
        _db.from('rooms').select('id').eq('hotel_id', hotelId!).eq('status', 'available'),
        _db.from('rooms').select('id').eq('hotel_id', hotelId!),
      ]);
      final guestName = (results[0] as List).isNotEmpty
          ? (results[0] as List).first['full_name'] as String
          : 'Guest';
      final roomNumber = (results[1] as List).isNotEmpty
          ? (results[1] as List).first['room_number'] as String
          : '—';
      final checkIn = booking.checkInDate.toIso8601String().substring(0, 10);
      final checkOut = booking.checkOutDate.toIso8601String().substring(0, 10);

      final ns = NotificationService(hotelId!);
      await ns.notifyNewReservation(
        guestName: guestName,
        roomNumber: roomNumber,
        bookingRef: booking.bookingRef,
        checkIn: checkIn,
        checkOut: checkOut,
      );

      // Low availability alert: warn when ≤ 20% rooms are available.
      // Dedup: skip if an unread low_availability notification was already
      // sent in the last hour to avoid notification spam when bulk-adding bookings.
      final available = (results[2] as List).length;
      final total = (results[3] as List).length;
      if (total > 0 && available / total <= 0.20) {
        final recentAlert = await _db
            .from('notifications')
            .select('id')
            .eq('hotel_id', hotelId!)
            .eq('type', 'low_availability')
            .eq('is_read', false)
            .gte('created_at', DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
            .limit(1);
        if ((recentAlert as List).isEmpty) {
          await ns.notifyLowAvailability(
            availableRooms: available,
            totalRooms: total,
          );
        }
      }
    } catch (_) {
      // Non-critical — never block main flow
    }
  }

  Future<void> updateBooking(Booking booking) async {
    await _bookingRepo.updateBooking(booking);
    await _syncBookingEffects(booking);
  }

  Future<void> deleteReservation(String bookingId) async {
    await _bookingRepo.deleteBooking(bookingId);
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
    return _guestRepo.getGuests();
  }

  Future<void> addGuest(Guest guest) async {
    await _guestRepo.addGuest(guest);
  }

  Future<void> updateGuest(Guest guest) async {
    await _guestRepo.updateGuest(guest);
  }

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    return _expenseRepo.getExpenses();
  }

  Future<List<Expense>> getRoomExpenses(String roomId) async {
    return _expenseRepo.getRoomExpenses(roomId);
  }

  Future<List<Expense>> getExpensesByBookingId(String bookingId) async {
    return _expenseRepo.getExpensesByBookingId(bookingId);
  }

  Future<void> addExpense(Expense expense) async {
    await _expenseRepo.addExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await _expenseRepo.updateExpense(expense);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _expenseRepo.deleteExpense(expenseId);
  }
}
