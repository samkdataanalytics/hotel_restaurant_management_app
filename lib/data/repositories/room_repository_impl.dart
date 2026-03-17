import '../../domain/entities/room.dart';
import '../../domain/repositories/room_repository.dart';
import '../datasources/local_data_source.dart';

class RoomRepositoryImpl implements RoomRepository {
  final LocalDataSource _dataSource;

  RoomRepositoryImpl(this._dataSource);

  @override
  Future<Room?> getRoom(String id) => _dataSource.getRoom(id);

  @override
  Future<List<Room>> getAllRooms() => _dataSource.getAllRooms();

  @override
  Future<void> updateRoom(Room room) => _dataSource.updateRoom(room);

  @override
  Future<void> addRoom(Room room) => _dataSource.insertRoom(room);

  @override
  Future<void> deleteRoom(String id) => _dataSource.deleteRoom(id);

  @override
  Future<List<Room>> getAvailableRooms() => _dataSource.getAvailableRooms();
}
