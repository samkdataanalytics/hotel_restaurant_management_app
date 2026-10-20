import '../di/injection_container.dart';
import '../data/datasources/supabase_data_source.dart';
import '../data/repositories/menu_item_repository_impl.dart';
import '../data/repositories/restaurant_table_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../data/repositories/ingredient_repository_impl.dart';
import '../domain/repositories/menu_item_repository.dart';
import '../domain/repositories/restaurant_table_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/ingredient_repository.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';

/// Points every tenant-scoped singleton at [propertyId].
///
/// Call this whenever the active property changes, BEFORE any work that reads
/// or writes tenant data. Missing any one of these assignments causes a silent
/// failure: reads return `[]` because the service bails on a null `hotelId`,
/// and writes omit `hotel_id` and fail the hotel-scoped RLS WITH CHECK with
/// Postgres error 42501. (That bug originally surfaced on Add Room, when
/// `SupabaseDataSource.hotelId` was the one left unset.)
///
/// Shared by the web shell (`AppShell._applyActiveProperty`) and the staff
/// mobile session so the two can never drift apart.
///
/// [bookingService] and [restaurantService] are passed in rather than read from
/// their singletons directly, so callers keep going through the Riverpod
/// providers and test overrides continue to work. Both are in practice the same
/// process-wide instance — see the `factory` constructors in their classes.
void applyPropertyScope({
  required BookingService bookingService,
  required RestaurantService restaurantService,
  required String propertyId,
}) {
  bookingService.hotelId = propertyId;
  restaurantService.hotelId = propertyId;

  // Clean Architecture repositories each carry their own hotelId.
  (sl<MenuItemRepository>() as MenuItemRepositoryImpl).hotelId = propertyId;
  (sl<RestaurantTableRepository>() as RestaurantTableRepositoryImpl).hotelId =
      propertyId;
  (sl<OrderRepository>() as OrderRepositoryImpl).hotelId = propertyId;
  (sl<IngredientRepository>() as IngredientRepositoryImpl).hotelId = propertyId;

  // Shared data source backs rooms, guests, bookings, check-ins and expenses.
  sl<SupabaseDataSource>().hotelId = propertyId;
}

/// The privilege tier a user holds on the active property.
class PropertyRole {
  /// Created the property — full admin, including team management.
  final bool isOwner;

  /// Owner, or a promoted staff member: full operational access. Managers
  /// bypass the per-section privilege map entirely.
  final bool isManager;

  const PropertyRole({required this.isOwner, required this.isManager});
}

/// Resolves what a raw `property_staff.role` value means for the current user.
///
/// [role] comes from `StaffService.getMyRoleForProperty`, which returns the
/// highest of `owner` > `manager` > `staff`, or null when the user appears in
/// neither `property_staff` nor the legacy `hotel_users`.
///
/// The null case is the subtle one and the reason this is shared rather than
/// reimplemented per platform:
///   * A regular account (an org owner) legitimately has no `property_staff`
///     row, so null means owner.
///   * A staff account (`@staff.internal`) with an unreadable role must fall
///     back to `staff`, never manager — otherwise a read failure silently
///     grants full operational access and lands them on a dashboard they have
///     no permission for.
PropertyRole resolvePropertyRole({
  required String? role,
  required bool isStaffAccount,
}) {
  final isOwner = !isStaffAccount && (role == null || role == 'owner');
  return PropertyRole(
    isOwner: isOwner,
    isManager: isOwner || role == 'manager',
  );
}
