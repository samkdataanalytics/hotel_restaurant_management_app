import 'package:uuid/uuid.dart';
import '../models/booking.dart';
import '../models/check_in.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/expense.dart';
import 'database_service.dart';

class BookingService {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  /// Generate the next auto-increment booking reference
  String getNextBookingRef() {
    return _db.generateNextBookingRef();
  }

  /// Look up a booking by its reference code
  Future<Map<String, dynamic>?> lookupBooking(String bookingRef) async {
    final booking = await _db.getBookingByRef(bookingRef);
    if (booking == null) return null;

    final guest = await _db.getGuest(booking.guestId);
    final room = await _db.getRoom(booking.roomId);

    return {
      'booking': booking,
      'guest': guest,
      'room': room,
    };
  }

  /// Perform check-in for a booking
  Future<Map<String, dynamic>> performCheckIn({
    required Booking booking,
    required Guest guest,
  }) async {
    // Update guest info
    await _db.updateGuest(guest);

    // Update booking status
    final updatedBooking = booking.copyWith(status: BookingStatus.checkedIn);
    await _db.updateBooking(updatedBooking);

    // Update room status
    final room = await _db.getRoom(booking.roomId);
    if (room != null) {
      final updatedRoom = room.copyWith(status: RoomStatus.occupied);
      await _db.updateRoom(updatedRoom);
    }

    // Create check-in record
    final checkIn = CheckIn(
      id: _uuid.v4(),
      bookingId: booking.id,
      guestId: guest.id,
      roomId: booking.roomId,
      checkInTime: DateTime.now(),
      idVerified: true,
      keyIssued: true,
    );
    await _db.insertCheckIn(checkIn);

    final updatedRoom = await _db.getRoom(booking.roomId);

    return {
      'checkIn': checkIn,
      'booking': updatedBooking,
      'guest': guest,
      'room': updatedRoom,
    };
  }

  /// Perform check-out for a booking
  Future<void> performCheckOut(String bookingId) async {
    final booking = await _db.getBooking(bookingId);
    if (booking == null) return;

    // Update booking status
    final updatedBooking = booking.copyWith(status: BookingStatus.checkedOut);
    await _db.updateBooking(updatedBooking);

    // Update room status
    final room = await _db.getRoom(booking.roomId);
    if (room != null) {
      final updatedRoom = room.copyWith(status: RoomStatus.available);
      await _db.updateRoom(updatedRoom);
    }
  }

  /// Get enriched check-in data with guest and room info
  Future<List<Map<String, dynamic>>> getEnrichedCheckIns() async {
    final checkIns = await _db.getAllCheckIns();
    final enriched = <Map<String, dynamic>>[];

    for (final checkIn in checkIns) {
      final guest = await _db.getGuest(checkIn.guestId);
      final room = await _db.getRoom(checkIn.roomId);
      final booking = await _db.getBooking(checkIn.bookingId);

      enriched.add({
        'checkIn': checkIn,
        'guest': guest,
        'room': room,
        'booking': booking,
      });
    }

    return enriched;
  }

  /// Get dashboard statistics
  Future<Map<String, int>> getDashboardStats() async {
    return _db.getDashboardStats();
  }

  /// Get all rooms
  Future<List<Room>> getAllRooms() async {
    return _db.getAllRooms();
  }

  /// Toggle room status
  Future<Room> toggleRoomStatus(Room room) async {
    RoomStatus newStatus;
    switch (room.status) {
      case RoomStatus.available:
        newStatus = RoomStatus.maintenance;
        break;
      case RoomStatus.maintenance:
        newStatus = RoomStatus.available;
        break;
      case RoomStatus.occupied:
        newStatus = RoomStatus.occupied;
        break;
    }

    final updated = room.copyWith(status: newStatus);
    await _db.updateRoom(updated);
    return updated;
  }

  /// Add a new room
  Future<void> addRoom(Room room) async {
    await _db.insertRoom(room);
  }

  /// Update an existing room
  Future<void> updateRoom(Room room) async {
    await _db.updateRoom(room);
  }

  /// Delete a room
  Future<void> deleteRoom(String roomId) async {
    await _db.deleteRoom(roomId);
  }

  /// Get all bookings with guest info
  Future<List<Map<String, dynamic>>> getEnrichedBookings() async {
    final bookings = await _db.getAllBookings();
    final enriched = <Map<String, dynamic>>[];

    for (final booking in bookings) {
      final guest = await _db.getGuest(booking.guestId);
      final room = await _db.getRoom(booking.roomId);
      enriched.add({
        'booking': booking,
        'guest': guest,
        'room': room,
      });
    }

    return enriched;
  }

  // ─── Reservation Management ───────────────────────────────

  /// Add a new reservation (manual entry)
  Future<void> addReservation(Booking booking) async {
    await _db.insertBooking(booking);
  }

  /// Update an existing reservation
  Future<void> updateBooking(Booking booking) async {
    await _db.updateBooking(booking);
  }

  /// Delete a reservation
  Future<void> deleteReservation(String bookingId) async {
    await _db.deleteBooking(bookingId);
  }

  /// Get all guests
  Future<List<Guest>> getAllGuests() async {
    return _db.getAllGuests();
  }

  /// Add a new guest
  Future<void> addGuest(Guest guest) async {
    await _db.insertGuest(guest);
  }

  /// Update an existing guest
  Future<void> updateGuest(Guest guest) async {
    await _db.updateGuest(guest);
  }

  // ─── Expense Management ───────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    return _db.getAllExpenses();
  }

  Future<List<Expense>> getRoomExpenses(String roomId) async {
    return _db.getRoomExpenses(roomId);
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.deleteExpense(expenseId);
  }
}
