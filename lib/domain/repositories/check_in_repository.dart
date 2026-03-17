import '../entities/check_in.dart';

abstract class CheckInRepository {
  Future<CheckIn?> getCheckIn(String id);
  Future<List<CheckIn>> getAllCheckIns();
  Future<void> insertCheckIn(CheckIn checkIn);
  Future<List<CheckIn>> getTodayCheckIns();
}
