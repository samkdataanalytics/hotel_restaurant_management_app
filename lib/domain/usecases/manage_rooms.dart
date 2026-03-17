import '../entities/room.dart';
import '../repositories/room_repository.dart';

class ManageRooms {
  final RoomRepository _roomRepository;

  ManageRooms(this._roomRepository);

  Future<List<Room>> getAllRooms() async {
    return _roomRepository.getAllRooms();
  }

  Future<void> addRoom(Room room) async {
    return _roomRepository.addRoom(room);
  }

  Future<void> updateRoom(Room room) async {
    return _roomRepository.updateRoom(room);
  }

  Future<void> deleteRoom(String id) async {
    return _roomRepository.deleteRoom(id);
  }

  Future<Room> toggleRoomStatus(Room room) async {
    RoomStatus newStatus;
    switch (room.status) {
      case RoomStatus.available:
        newStatus = RoomStatus.maintenance;
        break;
      case RoomStatus.maintenance:
        newStatus = RoomStatus.available;
        break;
      case RoomStatus.occupied:
        newStatus = RoomStatus.occupied; // Can't toggle occupied rooms
        break;
    }

    final updated = room.copyWith(status: newStatus);
    await _roomRepository.updateRoom(updated);
    return updated;
  }
}
