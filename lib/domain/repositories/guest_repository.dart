import '../entities/guest.dart';

abstract class GuestRepository {
  Future<Guest?> getGuest(String id);
  Future<List<Guest>> getAllGuests();
  Future<List<Guest>> getGuests(); 
  Future<void> insertGuest(Guest guest);
  Future<void> addGuest(Guest guest);
  Future<void> updateGuest(Guest guest);
  Future<void> deleteGuest(String id);
}
