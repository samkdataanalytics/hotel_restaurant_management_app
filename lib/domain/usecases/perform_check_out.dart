import '../entities/booking.dart';
import '../entities/room.dart';
import '../repositories/booking_repository.dart';
import '../repositories/room_repository.dart';

class PerformCheckOut {
  final BookingRepository _bookingRepository;
  final RoomRepository _roomRepository;

  PerformCheckOut(this._bookingRepository, this._roomRepository);

  Future<void> call(String bookingId) async {
    final booking = await _bookingRepository.getBooking(bookingId);
    if (booking == null) return;

    // Update booking status
    final updatedBooking = booking.copyWith(status: BookingStatus.checkedOut);
    await _bookingRepository.updateBooking(updatedBooking);

    // Update room status
    final room = await _roomRepository.getRoom(booking.roomId);
    if (room != null) {
      final updatedRoom = room.copyWith(status: RoomStatus.available);
      await _roomRepository.updateRoom(updatedRoom);
    }
  }
}
