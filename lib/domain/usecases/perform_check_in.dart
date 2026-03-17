import 'package:uuid/uuid.dart';
import '../entities/booking.dart';
import '../entities/check_in.dart';
import '../entities/guest.dart';
import '../entities/room.dart';
import '../repositories/booking_repository.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/guest_repository.dart';
import '../repositories/room_repository.dart';

class PerformCheckIn {
  final BookingRepository _bookingRepository;
  final GuestRepository _guestRepository;
  final RoomRepository _roomRepository;
  final CheckInRepository _checkInRepository;
  final _uuid = const Uuid();

  PerformCheckIn(
    this._bookingRepository,
    this._guestRepository,
    this._roomRepository,
    this._checkInRepository,
  );

  Future<Map<String, dynamic>> call({
    required Booking booking,
    required Guest guest,
  }) async {
    // Update guest info
    await _guestRepository.updateGuest(guest);

    // Update booking status
    final updatedBooking = booking.copyWith(status: BookingStatus.checkedIn);
    await _bookingRepository.updateBooking(updatedBooking);

    // Update room status
    final room = await _roomRepository.getRoom(booking.roomId);
    if (room != null) {
      final updatedRoom = room.copyWith(status: RoomStatus.occupied);
      await _roomRepository.updateRoom(updatedRoom);
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
    await _checkInRepository.insertCheckIn(checkIn);

    final updatedRoom = await _roomRepository.getRoom(booking.roomId);

    return {
      'checkIn': checkIn,
      'booking': updatedBooking,
      'guest': guest,
      'room': updatedRoom,
    };
  }
}
