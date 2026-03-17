import '../repositories/booking_repository.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/guest_repository.dart';
import '../repositories/room_repository.dart';

class GetEnrichedCheckIns {
  final CheckInRepository _checkInRepository;
  final GuestRepository _guestRepository;
  final RoomRepository _roomRepository;
  final BookingRepository _bookingRepository;

  GetEnrichedCheckIns(
    this._checkInRepository,
    this._guestRepository,
    this._roomRepository,
    this._bookingRepository,
  );

  Future<List<Map<String, dynamic>>> call() async {
    final checkIns = await _checkInRepository.getAllCheckIns();
    final enriched = <Map<String, dynamic>>[];

    for (final checkIn in checkIns) {
      final guest = await _guestRepository.getGuest(checkIn.guestId);
      final room = await _roomRepository.getRoom(checkIn.roomId);
      final booking = await _bookingRepository.getBooking(checkIn.bookingId);

      enriched.add({
        'checkIn': checkIn,
        'guest': guest,
        'room': room,
        'booking': booking,
      });
    }

    return enriched;
  }
}
