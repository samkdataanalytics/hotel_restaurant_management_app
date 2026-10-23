import 'package:get_it/get_it.dart';
import '../data/datasources/supabase_data_source.dart';
import '../data/repositories/booking_repository_impl.dart';
import '../data/repositories/room_repository_impl.dart';
import '../data/repositories/guest_repository_impl.dart';
import '../data/repositories/check_in_repository_impl.dart';
import '../data/repositories/expense_repository_impl.dart';
import '../data/repositories/menu_item_repository_impl.dart';
import '../data/repositories/restaurant_table_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../data/repositories/ingredient_repository_impl.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/repositories/room_repository.dart';
import '../domain/repositories/guest_repository.dart';
import '../domain/repositories/check_in_repository.dart';
import '../domain/repositories/expense_repository.dart';
import '../domain/repositories/menu_item_repository.dart';
import '../domain/repositories/restaurant_table_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/ingredient_repository.dart';
import '../domain/usecases/lookup_booking.dart';
import '../domain/usecases/perform_check_in.dart';
import '../domain/usecases/perform_check_out.dart';
import '../domain/usecases/get_dashboard_stats.dart';
import '../domain/usecases/get_enriched_check_ins.dart';
import '../domain/usecases/get_enriched_bookings.dart';
import '../domain/usecases/manage_rooms.dart';
import '../domain/usecases/manage_reservations.dart';
import '../services/restaurant_service.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ─── Data Sources ──────────────────────────────────────────
  final supabaseDataSource = SupabaseDataSource();
  sl.registerLazySingleton<SupabaseDataSource>(() => supabaseDataSource);

  // ─── Repositories (Hotel / Booking) ────────────────────────
  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<RoomRepository>(
    () => RoomRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<GuestRepository>(
    () => GuestRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<CheckInRepository>(
    () => CheckInRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(sl()),
  );

  // ─── Repositories (Restaurant) ─────────────────────────────
  sl.registerLazySingleton<MenuItemRepository>(
    () => MenuItemRepositoryImpl(),
  );
  sl.registerLazySingleton<RestaurantTableRepository>(
    () => RestaurantTableRepositoryImpl(),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(),
  );
  sl.registerLazySingleton<IngredientRepository>(
    () => IngredientRepositoryImpl(),
  );

  // ─── Services (Restaurant) ─────────────────────────────────
  sl.registerLazySingleton<RestaurantService>(() => RestaurantService());

  // ─── Use Cases ────────────────────────────────────────────
  sl.registerLazySingleton(() => LookupBooking(sl(), sl(), sl()));
  sl.registerLazySingleton(() => PerformCheckIn(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => PerformCheckOut(sl(), sl()));
  sl.registerLazySingleton(() => GetDashboardStats(sl(), sl(), sl()));
  sl.registerLazySingleton(() => GetEnrichedCheckIns(sl(), sl(), sl(), sl()));
  sl.registerLazySingleton(() => GetEnrichedBookings(sl(), sl(), sl()));
  sl.registerLazySingleton(() => ManageRooms(sl()));
  sl.registerLazySingleton(() => ManageReservations(sl(), sl(), sl()));
}
