import '../../domain/entities/guest.dart';
import '../../domain/repositories/guest_repository.dart';
import '../datasources/local_data_source.dart';

class GuestRepositoryImpl implements GuestRepository {
  final LocalDataSource _dataSource;

  GuestRepositoryImpl(this._dataSource);

  @override
  Future<Guest?> getGuest(String id) => _dataSource.getGuest(id);

  @override
  Future<List<Guest>> getAllGuests() => _dataSource.getAllGuests();

  @override
  Future<void> insertGuest(Guest guest) => _dataSource.insertGuest(guest);

  @override
  Future<void> updateGuest(Guest guest) => _dataSource.updateGuest(guest);
}
