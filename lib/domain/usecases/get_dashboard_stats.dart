import '../entities/booking.dart';
import '../entities/room.dart';
import '../repositories/booking_repository.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/room_repository.dart';

class GetDashboardStats {
  final CheckInRepository _checkInRepository;
  final RoomRepository _roomRepository;
  final BookingRepository _bookingRepository;

  GetDashboardStats(
    this._checkInRepository,
    this._roomRepository,
    this._bookingRepository,
  );

  Future<Map<String, int>> call() async {
    final todayCheckins = await _checkInRepository.getTodayCheckIns();
    final allRooms = await _roomRepository.getAllRooms();
    final occupied =
        allRooms.where((r) => r.status == RoomStatus.occupied).length;
    final available =
        allRooms.where((r) => r.status == RoomStatus.available).length;
    final pendingBookings =
        await _bookingRepository.getBookingsByStatus(BookingStatus.pending);

    return {
      'todayCheckIns': todayCheckins.length,
      'occupiedRooms': occupied,
      'availableRooms': available,
      'pendingArrivals': pendingBookings.length,
      'totalRooms': allRooms.length,
    };
  }
}
