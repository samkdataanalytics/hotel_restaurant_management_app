import '../repositories/booking_repository.dart';
import '../repositories/guest_repository.dart';
import '../repositories/room_repository.dart';

class LookupBooking {
  final BookingRepository _bookingRepository;
  final GuestRepository _guestRepository;
  final RoomRepository _roomRepository;

  LookupBooking(this._bookingRepository, this._guestRepository, this._roomRepository);

  Future<Map<String, dynamic>?> call(String bookingRef) async {
    final booking = await _bookingRepository.getBookingByRef(bookingRef);
    if (booking == null) return null;

    final guest = await _guestRepository.getGuest(booking.guestId);
    final room = await _roomRepository.getRoom(booking.roomId);

    return {
      'booking': booking,
      'guest': guest,
      'room': room,
    };
  }
}
