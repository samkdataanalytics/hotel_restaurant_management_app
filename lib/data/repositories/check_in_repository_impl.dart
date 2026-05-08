import '../../domain/entities/check_in.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../datasources/supabase_data_source.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  final SupabaseDataSource _dataSource;

  CheckInRepositoryImpl(this._dataSource);

  @override
  Future<CheckIn?> getCheckIn(String id) => _dataSource.getCheckIn(id);

  @override
  Future<List<CheckIn>> getAllCheckIns() => _dataSource.getAllCheckIns();

  @override
  Future<void> insertCheckIn(CheckIn checkIn) => _dataSource.insertCheckIn(checkIn);

  @override
  Future<List<CheckIn>> getTodayCheckIns() => _dataSource.getTodayCheckIns();

  @override
  Future<List<Map<String, dynamic>>> getEnrichedCheckIns() => _dataSource.getEnrichedCheckIns();
}
