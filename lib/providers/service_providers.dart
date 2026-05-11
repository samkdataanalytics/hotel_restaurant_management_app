import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';
import '../services/invoice_service.dart';
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

final bookingServiceProvider =
    Provider<BookingService>((_) => BookingService());

final restaurantServiceProvider =
    Provider<RestaurantService>((_) => RestaurantService());

final invoiceServiceProvider =
    Provider<InvoiceService>((_) => InvoiceService());

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
