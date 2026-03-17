import '../entities/guest.dart';

abstract class GuestRepository {
  Future<Guest?> getGuest(String id);
  Future<List<Guest>> getAllGuests();
  Future<void> insertGuest(Guest guest);
  Future<void> updateGuest(Guest guest);
}
