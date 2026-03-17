import '../entities/room.dart';

abstract class RoomRepository {
  Future<Room?> getRoom(String id);
  Future<List<Room>> getAllRooms();
  Future<void> updateRoom(Room room);
  Future<void> addRoom(Room room);
  Future<void> deleteRoom(String id);
  Future<List<Room>> getAvailableRooms();
}
