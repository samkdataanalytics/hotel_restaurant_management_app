import '../entities/booking.dart';

abstract class BookingRepository {
  Future<Booking?> getBooking(String id);
  Future<List<Booking>> getAllBookings();
  Future<Booking?> getBookingByRef(String ref);
  Future<void> insertBooking(Booking booking);
  Future<void> updateBooking(Booking booking);
  Future<void> deleteBooking(String id);
  Future<List<Booking>> getBookingsByStatus(BookingStatus status);
}
