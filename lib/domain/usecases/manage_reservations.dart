import '../entities/booking.dart';
import '../repositories/booking_repository.dart';
import '../repositories/guest_repository.dart';
import '../repositories/room_repository.dart';

class ManageReservations {
  final BookingRepository _bookingRepository;
  final GuestRepository _guestRepository;
  final RoomRepository _roomRepository;

  ManageReservations(
    this._bookingRepository,
    this._guestRepository,
    this._roomRepository,
  );

  Future<List<Booking>> getAllReservations() async {
    return _bookingRepository.getAllBookings();
  }

  Future<void> addReservation(Booking booking) async {
    return _bookingRepository.insertBooking(booking);
  }

  Future<void> updateReservation(Booking booking) async {
    return _bookingRepository.updateBooking(booking);
  }

  Future<void> deleteReservation(String id) async {
    return _bookingRepository.deleteBooking(id);
  }

  /// Get all enriched reservations (with guest + room data)
  Future<List<Map<String, dynamic>>> getEnrichedReservations() async {
    final bookings = await _bookingRepository.getAllBookings();
    final enriched = <Map<String, dynamic>>[];

    for (final booking in bookings) {
      final guest = await _guestRepository.getGuest(booking.guestId);
      final room = await _roomRepository.getRoom(booking.roomId);
      enriched.add({
        'booking': booking,
        'guest': guest,
        'room': room,
      });
    }

    return enriched;
  }
}
