import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';
import '../services/staff_service.dart';
import '../services/plan_service.dart';
import '../services/guest_menu_service.dart';
import '../services/lead_service.dart';
import '../services/organization_service.dart';

/// Riverpod providers for all application services.
///
/// All primary services are singletons, so each provider returns the same
/// instance for the lifetime of the app. Using ref.read(xServiceProvider)
/// instead of XService() directly allows providers to be overridden in tests.
///
/// Every service reachable from this file must compile on native as well as
/// web — the staff mobile app imports it. `invoiceServiceProvider` therefore
/// lives in `invoice_provider.dart` instead, because `invoice_service.dart`
/// depends on `dart:js_interop` / `package:web`.

final bookingServiceProvider =
    Provider<BookingService>((_) => BookingService());

final restaurantServiceProvider =
    Provider<RestaurantService>((_) => RestaurantService());

final staffServiceProvider =
    Provider<StaffService>((_) => StaffService());

final planServiceProvider =
    Provider<PlanService>((_) => PlanService());

final guestMenuServiceProvider =
    Provider<GuestMenuService>((_) => GuestMenuService());

final leadServiceProvider =
    Provider<LeadService>((_) => LeadService());

final organizationServiceProvider =
    Provider<OrganizationService>((_) => OrganizationService());
