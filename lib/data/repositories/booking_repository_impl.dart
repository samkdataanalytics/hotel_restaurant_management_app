import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/local_data_source.dart';

class BookingRepositoryImpl implements BookingRepository {
  final LocalDataSource _dataSource;

  BookingRepositoryImpl(this._dataSource);

  @override
  Future<Booking?> getBooking(String id) => _dataSource.getBooking(id);

  @override
  Future<List<Booking>> getAllBookings() => _dataSource.getAllBookings();

  @override
  Future<Booking?> getBookingByRef(String ref) => _dataSource.getBookingByRef(ref);

  @override
  Future<void> insertBooking(Booking booking) => _dataSource.insertBooking(booking);

  @override
  Future<void> updateBooking(Booking booking) => _dataSource.updateBooking(booking);

  @override
  Future<void> deleteBooking(String id) => _dataSource.deleteBooking(id);

  @override
  Future<List<Booking>> getBookingsByStatus(BookingStatus status) =>
      _dataSource.getBookingsByStatus(status);
}
