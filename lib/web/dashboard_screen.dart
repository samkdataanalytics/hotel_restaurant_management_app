import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:web/web.dart' as webpkg;
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/guest.dart';
import '../domain/entities/room.dart';
import '../domain/entities/restaurant_order.dart';
import '../providers/app_auth_provider.dart';
import '../providers/hotel_session.dart';
import '../di/injection_container.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/restaurant_table_repository.dart';
import '../domain/repositories/check_in_repository.dart';
import '../domain/usecases/get_dashboard_stats.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _orderRepo = sl<OrderRepository>();
  final _tableRepo = sl<RestaurantTableRepository>();
  final _checkInRepo = sl<CheckInRepository>();
  final _getDashboardStats = sl<GetDashboardStats>();
  final _timeFormat = DateFormat('hh:mm a');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  NumberFormat get _currency => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);

  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _recentCheckIns = [];
  bool _isLoading = true;
  String? _error;

  // Restaurant stats
  int _resTodayOrders = 0;
  double _resTodayRevenue = 0;
  int _resActiveKitchen = 0;
  int _resTablesOccupied = 0;
  int _resTotalTables = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _maybeReloadAfterPayment();
  }

  // When PayHere redirects back with ?upgraded=1, reload auth state so the
  // updated plan is reflected without requiring a manual refresh.
  void _maybeReloadAfterPayment() {
    final search = webpkg.window.location.search;
    if (!search.contains('upgraded=1')) return;
    // Give the webhook ~3 s to finish before reloading auth state.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      ref.read(authProvider.notifier).reload();
    });
  }

  Future<void> _loadData() async {
    try {
      final stats = await _getDashboardStats();
      final checkIns = await _checkInRepo.getEnrichedCheckIns();

      // Load restaurant stats only if property has both hotel and restaurant
      final property = ref.read(activePropertyProvider);
      if (property != null && property.type == 'both') {
        await _loadRestaurantStats();
      }

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _recentCheckIns = checkIns.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRestaurantStats() async {
    try {
      final orders = await _orderRepo.getOrders();
      final tables = await _tableRepo.getTables();
      final now = DateTime.now();

      final todayOrders = orders.where((o) =>
          o.createdAt.year == now.year &&
          o.createdAt.month == now.month &&
          o.createdAt.day == now.day &&
          o.status != OrderStatus.cancelled).toList();

      final todayRevenue = todayOrders
          .where((o) => o.paymentStatus == PaymentStatus.paid ||
                        o.paymentStatus == PaymentStatus.chargedToRoom)
          .fold(0.0, (s, o) => s + o.totalAmount);

      final activeKitchen = todayOrders
          .where((o) => o.status == OrderStatus.pending ||
                        o.status == OrderStatus.preparing)
          .length;

      // Tables occupied = tables that have at least one open (unpaid) order today
      final occupiedTableIds = todayOrders
          .where((o) => o.tableId != null &&
                        o.paymentStatus == PaymentStatus.unpaid &&
                        o.status != OrderStatus.cancelled)
          .map((o) => o.tableId)
          .toSet();

      if (!mounted) return;
      setState(() {
        _resTodayOrders = todayOrders.length;
        _resTodayRevenue = todayRevenue;
        _resActiveKitchen = activeKitchen;
        _resTablesOccupied = occupiedTableIds.length;
        _resTotalTables = tables.length;
      });
    } catch (_) {
      // Non-critical — restaurant stats are best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const DashboardSkeleton();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppTheme.screenPad(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  _isLoading = true;
                  _error = null;
                  _loadData();
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: AppTheme.screenPad(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back! Here\'s today\'s overview.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!AppTheme.isMobile(context))
                  Text(
                    _dateFormat.format(DateTime.now()),
                    style: TextStyle(
                      color: AppTheme.adminTextMuted,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Enterprise subscription payment banner
            _SubscriptionPayBanner(ref: ref),

            // Stats cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 48) / 4
                    : constraints.maxWidth > 600
                        ? (constraints.maxWidth - 24) / 2
                        : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _statCard(
                      'Today\'s Check-ins',
                      '${_stats['todayCheckIns'] ?? 0}',
                      Icons.login_rounded,
                      AppTheme.adminPrimary,
                      cardWidth,
                    ),
                    _statCard(
                      'Occupied Rooms',
                      '${_stats['occupiedRooms'] ?? 0}',
                      Icons.king_bed_rounded,
                      AppTheme.success,
                      cardWidth,
                    ),
                    _statCard(
                      'Available Rooms',
                      '${_stats['availableRooms'] ?? 0}',
                      Icons.meeting_room_rounded,
                      AppTheme.warning,
                      cardWidth,
                    ),
                    _statCard(
                      'Pending Arrivals',
                      '${_stats['pendingArrivals'] ?? 0}',
                      Icons.schedule_rounded,
                      const Color(0xFF8B5CF6),
                      cardWidth,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Restaurant stats (only when property has both hotel and restaurant)
            if (ref.watch(activePropertyProvider)?.type == 'both') ...[
              Text(
                'Restaurant Overview',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 900
                      ? (constraints.maxWidth - 48) / 4
                      : constraints.maxWidth > 600
                          ? (constraints.maxWidth - 24) / 2
                          : constraints.maxWidth;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _statCard(
                        'Today\'s Orders',
                        '$_resTodayOrders',
                        Icons.receipt_long_rounded,
                        AppTheme.restaurantAccent,
                        cardWidth,
                      ),
                      _statCard(
                        'Today\'s Revenue',
                        _currency.format(_resTodayRevenue),
                        Icons.trending_up_rounded,
                        AppTheme.success,
                        cardWidth,
                      ),
                      _statCard(
                        'Active Kitchen',
                        '$_resActiveKitchen',
                        Icons.restaurant_menu_rounded,
                        _resActiveKitchen > 0 ? AppTheme.warning : const Color(0xFF8B5CF6),
                        cardWidth,
                      ),
                      _statCard(
                        'Tables Occupied',
                        '$_resTablesOccupied / $_resTotalTables',
                        Icons.table_restaurant_rounded,
                        const Color(0xFF0EA5E9),
                        cardWidth,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],

            // Room occupancy bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room Occupancy',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          children: [
                            Expanded(
                              flex: _stats['occupiedRooms'] ?? 0,
                              child: Container(
                                color: AppTheme.success,
                                alignment: Alignment.center,
                                child: Text(
                                  'Occupied (${_stats['occupiedRooms'] ?? 0})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: _stats['availableRooms'] ?? 0,
                              child: Container(
                                color: AppTheme.adminPrimary,
                                alignment: Alignment.center,
                                child: Text(
                                  'Available (${_stats['availableRooms'] ?? 0})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent check-ins table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Check-ins',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_recentCheckIns.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No check-ins yet',
                              style: TextStyle(color: AppTheme.adminTextMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Guest')),
                            DataColumn(label: Text('Room')),
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('ID Verified')),
                            DataColumn(label: Text('Key Issued')),
                          ],
                          rows: _recentCheckIns.map((data) {
                            final checkIn = data['checkIn'] as CheckIn;
                            final guest = data['guest'] as Guest?;
                            final room = data['room'] as Room?;

                            return DataRow(cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          AppTheme.adminPrimary.withOpacity(0.1),
                                      child: Text(
                                        (guest?.fullName ?? '?')[0],
                                        style: TextStyle(
                                          color: AppTheme.adminPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(guest?.fullName ?? 'Unknown'),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.adminPrimary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    room?.roomNumber ?? '-',
                                    style: TextStyle(
                                      color: AppTheme.adminPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(_timeFormat.format(checkIn.checkInTime)),
                              ),
                              DataCell(
                                Icon(
                                  checkIn.idVerified
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: checkIn.idVerified
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                  size: 20,
                                ),
                              ),
                              DataCell(
                                Icon(
                                  checkIn.keyIssued
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: checkIn.keyIssued
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                  size: 20,
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.adminTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Enterprise subscription payment banner ───────────────────────────────────

class _SubscriptionPayBanner extends StatelessWidget {
  final WidgetRef ref;
  const _SubscriptionPayBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(authProvider).valueOrNull?.organization;
    if (org == null || !org.hasCustomSubscription) return const SizedBox.shrink();

    final amount     = org.effectiveCustomPrice!;
    final cycle      = org.billingCycle ?? 'monthly';
    final cycleLabel = cycle == 'annually' ? 'annually' : 'monthly';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Enterprise Subscription',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(
            'LKR ${amount.toStringAsFixed(2)} / $cycleLabel · tap to pay via PayHere',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ])),
        ElevatedButton(
          onPressed: () => context.go('/app/pay-subscription'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF7C3AED),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Pay Now',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
