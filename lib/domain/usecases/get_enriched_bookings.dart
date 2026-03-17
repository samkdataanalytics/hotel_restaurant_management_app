import '../repositories/booking_repository.dart';
import '../repositories/guest_repository.dart';
import '../repositories/room_repository.dart';

class GetEnrichedBookings {
  final BookingRepository _bookingRepository;
  final GuestRepository _guestRepository;
  final RoomRepository _roomRepository;

  GetEnrichedBookings(
    this._bookingRepository,
    this._guestRepository,
    this._roomRepository,
  );

  Future<List<Map<String, dynamic>>> call() async {
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
