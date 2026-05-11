import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../domain/entities/booking.dart';
import '../domain/entities/guest.dart';
import '../domain/entities/room.dart';
import 'widgets/responsive_dialog.dart';
import 'package:provider/provider.dart' as pkg_provider;
import '../providers/hotel_session.dart';
import '../services/invoice_service.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/repositories/room_repository.dart';
import '../di/injection_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'guest_responses_dialog.dart';
import '../domain/entities/staff_permission.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';
import '../providers/service_providers.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  BookingService get _bookingService => ref.read(bookingServiceProvider);
  RestaurantService get _restaurantService => ref.read(restaurantServiceProvider);
  InvoiceService get _invoiceService => ref.read(invoiceServiceProvider);
  final _bookingRepo       = sl<BookingRepository>();
  final _roomRepo          = sl<RoomRepository>();
  final _dateFormat = DateFormat('MMM dd');
  final _fullDateFormat = DateFormat('MMM dd, yyyy');
  String get _sym => pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';

  List<Map<String, dynamic>> _enrichedBookings = [];
  List<Room> _rooms = [];
  bool _isLoading = true;

  // Gantt calendar state — 14-day window
  late DateTime _windowStart;
  Map<String, dynamic>? _selectedCell; // {room, date}

  // Source filter
  final Set<BookingSource> _activeFilters = {
    BookingSource.bookingCom,
    BookingSource.airbnb,
    BookingSource.direct,
    BookingSource.other,
  };

  List<BookingSource> get _enabledSources => BookingSource.values;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Start window 1 day before today so today is visible
    _windowStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await _bookingRepo.getEnrichedBookings();
      final rooms = await _roomRepo.getAllRooms();
      if (!mounted) return;
      setState(() {
        _enrichedBookings = bookings;
        _rooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reservations: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────

  List<DateTime> get _dateColumns {
    return List.generate(14, (i) => _windowStart.add(Duration(days: i)));
  }

  Color _sourceColor(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom: return const Color(0xFF003580);
      case BookingSource.airbnb:     return const Color(0xFFFF5A5F);
      case BookingSource.expedia:    return const Color(0xFF00355F);
      case BookingSource.direct:     return AppTheme.success;
      case BookingSource.other:      return AppTheme.warning;
    }
  }

  IconData _sourceIcon(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom: return Icons.language_rounded;
      case BookingSource.airbnb:     return Icons.house_rounded;
      case BookingSource.expedia:    return Icons.flight_rounded;
      case BookingSource.direct:     return Icons.phone_in_talk_rounded;
      case BookingSource.other:      return Icons.more_horiz_rounded;
    }
  }

  String _sourceLabel(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom: return 'Booking.com';
      case BookingSource.airbnb:     return 'Airbnb';
      case BookingSource.expedia:    return 'Expedia';
      case BookingSource.direct:     return 'Direct';
      case BookingSource.other:      return 'Other';
    }
  }

  bool _bookingSpansDay(Booking booking, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final checkIn = DateTime(booking.checkInDate.year, booking.checkInDate.month, booking.checkInDate.day);
    final checkOut = DateTime(booking.checkOutDate.year, booking.checkOutDate.month, booking.checkOutDate.day);
    return checkIn.isBefore(dayEnd) && checkOut.isAfter(dayStart);
  }

  /// Get the booking for a specific room on a specific day (filtered)
  /// Returns the booking occupying [room] on [day], regardless of source filter.
  /// Used for calendar cell colour / availability — a room is never "free" just
  /// because its source is hidden in the filter panel.
  Map<String, dynamic>? _getBookingForRoomOnDay(Room room, DateTime day) {
    for (final data in _enrichedBookings) {
      final booking = data['booking'] as Booking;
      if (booking.roomId != room.id) continue;
      if (_bookingSpansDay(booking, day)) return data;
    }
    return null;
  }

  /// Get all bookings for a specific day that match the active source filter.
  /// Used only for the booking list / day-view counts — not for availability.
  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    return _enrichedBookings.where((data) {
      final booking = data['booking'] as Booking;
      if (!_activeFilters.contains(booking.source)) return false;
      return _bookingSpansDay(booking, day);
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _goBack() => setState(() => _windowStart = _windowStart.subtract(const Duration(days: 7)));
  void _goForward() => setState(() => _windowStart = _windowStart.add(const Duration(days: 7)));
  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _windowStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    });
  }

  Future<void> _showAddReservationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ReservationFormDialog(
        rooms: _rooms,
        bookingService: _bookingService,
        bookingRepo: _bookingRepo,
        enrichedBookings: _enrichedBookings,
        enabledSources: _enabledSources,
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _showEditReservationDialog(Map<String, dynamic> data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ReservationFormDialog(
        rooms: _rooms,
        bookingService: _bookingService,
        bookingRepo: _bookingRepo,
        existingData: data,
        enrichedBookings: _enrichedBookings,
        enabledSources: _enabledSources,
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _deleteReservation(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Reservation'),
          ],
        ),
        content: Text(
          'Delete reservation ${booking.bookingRef}? This action cannot be undone.',
          style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.adminTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _bookingService.deleteReservation(booking.id);
      await _loadData();
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const TableListSkeleton(rowCount: 8, cellCount: 5);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: AppTheme.screenPad(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSourceFilters(),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildGanttCalendar()),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _buildDetailPanel()),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildGanttCalendar(),
                      const SizedBox(height: 20),
                      _buildDetailPanel(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reservations', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(
                'Manage all reservations from Booking.com, Airbnb & direct bookings.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: canEditSection(ref, 'hotel_reservations') ? _showAddReservationDialog : null,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: AppTheme.isMobile(context)
                  ? const SizedBox.shrink()
                  : const Text('Add Reservation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.adminPrimary,
                foregroundColor: Colors.white,
                padding: AppTheme.isMobile(context)
                    ? const EdgeInsets.all(14)
                    : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Source Filters ───────────────────────────────────────

  Widget _buildSourceFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _enabledSources.map((source) {
        final isActive = _activeFilters.contains(source);
        final color = _sourceColor(source);
        final count = _enrichedBookings
            .where((d) => (d['booking'] as Booking).source == source)
            .length;

        return GestureDetector(
          onTap: () => setState(() {
            isActive ? _activeFilters.remove(source) : _activeFilters.add(source);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isActive ? color : Colors.grey.shade300, width: 1.5),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_sourceIcon(source), size: 16, color: isActive ? Colors.white : color),
                const SizedBox(width: 8),
                Text(
                  _sourceLabel(source),
                  style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.adminTextMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withOpacity(0.25) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.adminTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Gantt Calendar ───────────────────────────────────────

  Widget _buildGanttCalendar() {
    final dates = _dateColumns;
    final totalRooms = _rooms.length;
    const double roomColWidth = 100;
    const double dayCellWidth = 80;
    const double rowHeight = 44;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Navigation bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: _goBack, icon: const Icon(Icons.chevron_left_rounded), splashRadius: 20),
                    Text(
                      '${_dateFormat.format(dates.first)} — ${_dateFormat.format(dates.last)}, ${dates.last.year}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    IconButton(onPressed: _goForward, icon: const Icon(Icons.chevron_right_rounded), splashRadius: 20),
                  ],
                ),
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Today'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scrollable Gantt grid
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date header row ──
                  Row(
                    children: [
                      Container(
                        width: roomColWidth,
                        height: rowHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('Room', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.adminTextMuted, fontSize: 12)),
                      ),
                      ...dates.map((date) {
                        final today = _isToday(date);
                        final isSelected = _selectedCell != null && _selectedCell!['room'] == null && _selectedCell!['date'] == date;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCell = {'date': date}),
                          child: Container(
                            width: dayCellWidth,
                            height: rowHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: today ? AppTheme.adminPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? AppTheme.adminPrimary : Colors.transparent,
                                width: isSelected && !today ? 2 : 0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('EEE').format(date),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: today ? Colors.white : AppTheme.adminTextMuted),
                                ),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: today ? Colors.white : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const Divider(height: 1),

                  // ── Summary row — Reserved / Available / Maintenance ──
                  Row(
                    children: [
                      Container(
                        width: roomColWidth,
                        height: rowHeight,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('Summary', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.adminTextMuted, fontSize: 11)),
                      ),
                      ...dates.map((date) {
                        int reserved = 0;
                        int maintenance = 0;
                        for (final room in _rooms) {
                          if (room.isUnderMaintenanceOn(date)) {
                            maintenance++;
                          } else if (_getBookingForRoomOnDay(room, date) != null) {
                            reserved++;
                          }
                        }
                        final available = totalRooms - reserved - maintenance;

                        return Container(
                          width: dayCellWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _miniPill(reserved, AppTheme.danger),
                                  const SizedBox(width: 3),
                                  _miniPill(available, AppTheme.success),
                                  if (maintenance > 0) ...[
                                    const SizedBox(width: 3),
                                    _miniPill(maintenance, AppTheme.warning),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),

                  // ── Revenue row ──
                  Row(
                    children: [
                      Container(
                        width: roomColWidth,
                        height: 28,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Icon(Icons.attach_money, size: 12, color: AppTheme.success),
                            Text(' Revenue', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.adminTextMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      ...dates.map((date) {
                        final dayBookings = _getBookingsForDay(date);
                        double total = 0;
                        for (final d in dayBookings) {
                          final b = d['booking'] as Booking;
                          if (b.nights > 0) {
                            total += b.totalAmount / b.nights;
                          }
                        }
                        return Container(
                          width: dayCellWidth,
                          height: 28,
                          alignment: Alignment.center,
                          child: Text(
                            total > 0 ? '$_sym${total.toStringAsFixed(0)}' : '-',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: total > 0 ? AppTheme.success : Colors.grey.shade400,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const Divider(height: 1),

                  // ── Room rows ──
                  ...List.generate(_rooms.length, (roomIndex) {
                    final room = _rooms[roomIndex];
                    final isEven = roomIndex % 2 == 0;

                    return Row(
                      children: [
                        // Room label
                        Container(
                          width: roomColWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.only(left: 8),
                          color: isEven ? Colors.grey.shade50 : Colors.white,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(room.roomNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text(room.typeLabel, style: TextStyle(fontSize: 10, color: AppTheme.adminTextMuted)),
                            ],
                          ),
                        ),
                        // Day cells
                        ...dates.map((date) {
                          final isMaintenance = room.isUnderMaintenanceOn(date);
                          final bookingData = isMaintenance ? null : _getBookingForRoomOnDay(room, date);
                          final isSelected = _selectedCell != null &&
                              _selectedCell!['room'] != null &&
                              (_selectedCell!['room'] as Room).id == room.id &&
                              (_selectedCell!['date'] as DateTime) == date;

                          final isSourceVisible = bookingData == null ||
                              _activeFilters.contains((bookingData['booking'] as Booking).source);
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCell = {'room': room, 'date': date}),
                            child: Container(
                              width: dayCellWidth,
                              height: rowHeight,
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: isMaintenance
                                    ? Colors.orange.shade50
                                    : bookingData != null
                                        ? isSourceVisible
                                            ? _sourceColor((bookingData['booking'] as Booking).source).withOpacity(0.12)
                                            : Colors.grey.shade200
                                        : isEven
                                            ? Colors.grey.shade50
                                            : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.adminPrimary
                                      : Colors.transparent,
                                  width: isSelected ? 2 : 0,
                                ),
                              ),
                              child: isMaintenance
                                  ? Center(
                                      child: Icon(Icons.build_rounded, size: 14, color: AppTheme.warning),
                                    )
                                  : bookingData != null
                                      ? _buildCellContent(bookingData, sourceVisible: isSourceVisible)
                                      : const SizedBox.shrink(),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),

            // Legend
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _legendItem(AppTheme.danger, 'Reserved'),
                _legendItem(AppTheme.success, 'Available'),
                _legendItem(AppTheme.warning, 'Maintenance'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPill(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(3), border: Border.all(color: color, width: 1))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.adminTextMuted, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCellContent(Map<String, dynamic> data, {bool sourceVisible = true}) {
    final booking = data['booking'] as Booking;
    final guest = data['guest'] as Guest?;
    final color = sourceVisible ? _sourceColor(booking.source) : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sourceVisible ? (guest?.fullName.split(' ').first ?? '?') : booking.sourceLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            booking.bookingRef,
            style: TextStyle(fontSize: 8, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  // ─── Detail Panel ─────────────────────────────────────────

  Widget _buildDetailPanel() {
    if (_selectedCell == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildEmptyState(
            icon: Icons.touch_app_rounded,
            message: 'Click on a cell or date to see details',
          ),
        ),
      );
    }

    final date = _selectedCell!['date'] as DateTime;
    final dayBookings = _getBookingsForDay(date);

    // Calculate day stats
    int dayReserved = 0, dayMaintenance = 0;
    for (final r in _rooms) {
      if (r.isUnderMaintenanceOn(date)) {
        dayMaintenance++;
      } else if (_getBookingForRoomOnDay(r, date) != null) {
        dayReserved++;
      }
    }
    final dayAvailable = _rooms.length - dayReserved - dayMaintenance;
    double dayRevenue = 0;
    for (final d in dayBookings) {
      final b = d['booking'] as Booking;
      if (b.nights > 0) dayRevenue += b.totalAmount / b.nights;
    }

    // ─── Room View ───
    if (_selectedCell!['room'] != null) {
      final room = _selectedCell!['room'] as Room;
      final bookingData = _getBookingForRoomOnDay(room, date);
      final isMaintenance = room.isUnderMaintenanceOn(date);

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fullDateFormat.format(date), style: AppTheme.dmSerif(fontSize: 18)),
              const SizedBox(height: 4),
              Text('Room ${room.roomNumber} — ${room.typeLabel}', style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13)),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  children: [
                    _statColumn(dayReserved.toString(), 'Booked', AppTheme.danger),
                    _statColumn(dayAvailable.toString(), 'Available', AppTheme.success),
                    _statColumn(dayMaintenance.toString(), 'Maint.', AppTheme.warning),
                    _statColumn('$_sym${dayRevenue.toStringAsFixed(0)}', 'Revenue', AppTheme.adminPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (isMaintenance) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.warning.withOpacity(0.3))),
                  child: Column(
                    children: [
                      Icon(Icons.build_rounded, color: AppTheme.warning, size: 32),
                      const SizedBox(height: 8),
                      Text('Under Maintenance', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.warning)),
                      if (room.maintenanceStart != null && room.maintenanceEnd != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('${_fullDateFormat.format(room.maintenanceStart!)} — ${_fullDateFormat.format(room.maintenanceEnd!)}', style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted)),
                        ),
                    ],
                  ),
                ),
              ] else if (bookingData != null) ...[
                _buildReservationTile(bookingData),
              ] else ...[
                _buildEmptyState(icon: Icons.event_available_rounded, message: 'This room is available'),
              ],
            ],
          ),
        ),
      );
    }

    // ─── Day View (All Reservations) ───
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_fullDateFormat.format(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Daily Overview', style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 13)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  _statColumn(dayReserved.toString(), 'Booked', AppTheme.danger),
                  _statColumn(dayAvailable.toString(), 'Available', AppTheme.success),
                  _statColumn(dayMaintenance.toString(), 'Maint.', AppTheme.warning),
                  _statColumn('$_sym${dayRevenue.toStringAsFixed(0)}', 'Revenue', AppTheme.adminPrimary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Text('Reservations (${dayBookings.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            
            if (dayBookings.isEmpty)
              _buildEmptyState(icon: Icons.bed_outlined, message: 'No reservations for this day.')
            else
              ...dayBookings.map((data) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReservationTile(data),
              )),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.adminTextMuted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildReservationTile(Map<String, dynamic> data) {
    final booking = data['booking'] as Booking;
    final guest = data['guest'] as Guest?;
    final room = data['room'] as Room?;
    final color = _sourceColor(booking.source);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_sourceIcon(booking.source), size: 14, color: color),
                const SizedBox(width: 6),
                Text(booking.sourceLabel, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(booking.bookingRef, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: color.withOpacity(0.1),
                      child: Text((guest?.fullName ?? '?')[0], style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guest?.fullName ?? 'Unknown Guest', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('Room ${room?.roomNumber ?? '-'}  •  ${booking.numberOfGuests} guest${booking.numberOfGuests > 1 ? 's' : ''}',
                            style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.login_rounded, size: 14, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(_fullDateFormat.format(booking.checkInDate), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.logout_rounded, size: 14, color: AppTheme.danger),
                    const SizedBox(width: 4),
                    Text(_fullDateFormat.format(booking.checkOutDate), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('(${booking.nights}n)', style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 11)),
                  ],
                ),
                if (booking.specialRequests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_outlined, size: 13, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            booking.specialRequests,
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (booking.totalAmount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 14, color: AppTheme.success),
                      const SizedBox(width: 4),
                      Text(
                        '$_sym${booking.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success),
                      ),
                      const SizedBox(width: 8),
                      Text('(\$${(booking.totalAmount / (booking.nights > 0 ? booking.nights : 1)).toStringAsFixed(0)}/night)',
                        style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 11)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statusBadge(booking),
                    const SizedBox(width: 8),
                    if (booking.isPaid)
                      _paidBadge(),
                    if (booking.isPaid)
                      const SizedBox(width: 8),
                    if (booking.isGuestFormSubmitted)
                      _guestFormBadge(booking, guest)
                    else if (booking.isQrGenerated)
                      _qrGeneratedBadge(),
                    const Spacer(),
                    if (!booking.isGuestFormSubmitted)
                      _tileAction(icon: Icons.qr_code_2_rounded, tooltip: 'Show QR Code', color: AppTheme.adminPrimary, onTap: () => _showQrDialog(booking)),
                    const SizedBox(width: 4),
                    if (guest != null && room != null)
                      _tileAction(icon: Icons.receipt_long_rounded, tooltip: 'Print Guest Folio', color: AppTheme.success, onTap: () => _printInvoice(booking, room, guest)),
                    const SizedBox(width: 4),
                    if (canEditSection(ref, 'hotel_reservations')) ...[
                    _tileAction(icon: Icons.edit_outlined, tooltip: 'Edit', color: AppTheme.adminPrimary, onTap: () => _showEditReservationDialog(data)),
                    const SizedBox(width: 4),
                    _tileAction(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: AppTheme.danger, onTap: () => _deleteReservation(booking)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Booking booking) {
    Color badgeColor;
    switch (booking.status) {
      case BookingStatus.pending:
        badgeColor = AppTheme.warning;
        break;
      case BookingStatus.checkedIn:
        badgeColor = AppTheme.success;
        break;
      case BookingStatus.checkedOut:
        badgeColor = AppTheme.adminTextMuted;
        break;
      case BookingStatus.cancelled:
        badgeColor = AppTheme.danger;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(booking.statusLabel, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _paidBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
          const SizedBox(width: 4),
          Text('Paid', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _qrGeneratedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 12, color: AppTheme.warning),
          const SizedBox(width: 4),
          Text('QR Sent', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _guestFormBadge(Booking booking, Guest? guest) {
    return InkWell(
      onTap: () {
        if (guest != null) {
          showDialog(
            context: context,
            builder: (context) => GuestResponsesDialog(booking: booking, guest: guest),
          );
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 12, color: AppTheme.success),
            const SizedBox(width: 4),
            Text('Form Sub.', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _showQrDialog(Booking booking) async {
    final baseUrl = Uri.base.origin; // Gets e.g 'http://localhost:8080' or whatever is being used
    final url = '$baseUrl/guest-registration?ref=${booking.bookingRef}';

    if (!booking.isQrGenerated) {
      final updated = booking.copyWith(isQrGenerated: true);
      await _bookingService.updateBooking(updated);
      _loadData();
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => ResponsiveDialog(
        maxWidth: 380,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Guest Registration QR: ${booking.bookingRef}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                  'Ask the guest to scan this QR code to securely fill out their information and preferences.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
                const SizedBox(height: 12),
                SelectableText(url, style: TextStyle(fontSize: 12, color: AppTheme.adminPrimary), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy URL'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _tileAction({required IconData icon, required String tooltip, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  Future<void> _printInvoice(Booking booking, Room room, Guest guest) async {
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    void dismissDialog() {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }
    }

    try {
      final session = pkg_provider.Provider.of<HotelSession>(context, listen: false);
      _restaurantService.hotelId = session.hotelId;

      final settings = session.settings;

      // Fetch DB data + warm up fonts/logo all in parallel
      final expensesFuture  = _bookingService.getAllExpenses();
      final ordersFuture    = _restaurantService.getChargedToRoomOrders(booking.id);
      final warmUpFuture    = _invoiceService.warmUp(settings?.logoUrl ?? '');
      final expenses         = await expensesFuture;
      final restaurantOrders = await ordersFuture;
      await warmUpFuture;

      // PDF is already warm — generation is now fast
      await _invoiceService.displayInvoicePdf(
        booking:          booking,
        room:             room,
        guest:            guest,
        expenses:         expenses,
        restaurantOrders: restaurantOrders,
        currencySymbol:   settings?.currencySymbol ?? '\$',
        settings:         settings,
      );

      dismissDialog();
    } catch (e) {
      dismissDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate guest folio: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─── Reservation Form Dialog ────────────────────────────────

class _ReservationFormDialog extends StatefulWidget {
  final List<Room> rooms;
  final BookingService bookingService;
  final BookingRepository bookingRepo;
  final List<Map<String, dynamic>> enrichedBookings;
  final List<BookingSource> enabledSources;
  final Map<String, dynamic>? existingData;

  const _ReservationFormDialog({
    required this.rooms,
    required this.bookingService,
    required this.bookingRepo,
    required this.enrichedBookings,
    required this.enabledSources,
    this.existingData,
  });

  @override
  State<_ReservationFormDialog> createState() => _ReservationFormDialogState();
}

class _ReservationFormDialogState extends State<_ReservationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  String get _sym => pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';

  late final TextEditingController _guestNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _guestsCountController;
  late final TextEditingController _specialRequestsController;
  late final TextEditingController _amountController;

  late BookingSource _selectedSource;
  late BookingStatus _selectedStatus;
  String? _selectedRoomId;
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  bool _isPaid = false;

  bool get _isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    final existingBooking = widget.existingData?['booking'] as Booking?;
    final existingGuest = widget.existingData?['guest'] as Guest?;

    _guestNameController = TextEditingController(text: existingGuest?.fullName ?? '');
    _emailController = TextEditingController(text: existingGuest?.email ?? '');
    _phoneController = TextEditingController(text: existingGuest?.phone ?? '');
    _guestsCountController = TextEditingController(text: existingBooking?.numberOfGuests.toString() ?? '1');
    _specialRequestsController = TextEditingController(text: existingBooking?.specialRequests ?? '');
    _amountController = TextEditingController(text: existingBooking?.totalAmount.toStringAsFixed(2) ?? '');

    _selectedSource = existingBooking?.source ??
        (widget.enabledSources.isNotEmpty ? widget.enabledSources.first : BookingSource.direct);
    _selectedStatus = existingBooking?.status ?? BookingStatus.pending;
    _selectedRoomId = existingBooking?.roomId;
    _checkInDate = existingBooking?.checkInDate;
    _checkOutDate = existingBooking?.checkOutDate;
    _isPaid = existingBooking?.isPaid ?? false;
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _guestsCountController.dispose();
    _specialRequestsController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Get rooms available for booking (exclude rooms under maintenance or already booked for selected dates)
  List<Room> get _availableRooms {
    if (_checkInDate == null || _checkOutDate == null) return widget.rooms;

    final existingBookingId = (widget.existingData?['booking'] as Booking?)?.id;

    return widget.rooms.where((room) {
      // Allow the currently selected room in edit mode
      if (_isEditing && room.id == _selectedRoomId) return true;
      // Exclude rooms under maintenance for the date range
      if (room.maintenanceOverlapsWith(_checkInDate!, _checkOutDate!)) return false;
      // Exclude rooms that have an overlapping booking
      final hasConflict = widget.enrichedBookings.any((data) {
        final booking = data['booking'] as Booking;
        if (booking.roomId != room.id) return false;
        // Skip the current booking being edited
        if (existingBookingId != null && booking.id == existingBookingId) return false;
        // Skip cancelled bookings
        if (booking.status == BookingStatus.cancelled) return false;
        // Check date overlap
        final bStart = DateTime(booking.checkInDate.year, booking.checkInDate.month, booking.checkInDate.day);
        final bEnd = DateTime(booking.checkOutDate.year, booking.checkOutDate.month, booking.checkOutDate.day);
        final rStart = DateTime(_checkInDate!.year, _checkInDate!.month, _checkInDate!.day);
        final rEnd = DateTime(_checkOutDate!.year, _checkOutDate!.month, _checkOutDate!.day);
        return rStart.isBefore(bEnd) && rEnd.isAfter(bStart);
      });
      if (hasConflict) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDate(bool isCheckIn) async {
    final result = await showDatePicker(
      context: context,
      initialDate: (isCheckIn ? _checkInDate : _checkOutDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: AppTheme.adminPrimary)),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = result;
          if (_checkOutDate == null || _checkOutDate!.isBefore(result)) {
            _checkOutDate = result.add(const Duration(days: 1));
          }
        } else {
          _checkOutDate = result;
        }
        // Reset room selection if the selected room is now under maintenance
        if (_selectedRoomId != null) {
          final selectedRoom = widget.rooms.firstWhere((r) => r.id == _selectedRoomId, orElse: () => widget.rooms.first);
          if (_checkInDate != null && _checkOutDate != null && selectedRoom.maintenanceOverlapsWith(_checkInDate!, _checkOutDate!)) {
            _selectedRoomId = null;
          }
        }
      });
    }
  }

  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please select check-in and check-out dates'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      );
      return;
    }
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please select a room'), backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      );
      return;
    }

    final existingBooking = widget.existingData?['booking'] as Booking?;
    final existingGuest = widget.existingData?['guest'] as Guest?;

    // Create or update guest
    final guestId = existingGuest?.id ?? _uuid.v4();
    final guest = Guest(
      id: guestId,
      fullName: _guestNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      idType: existingGuest?.idType ?? '',
      idNumber: existingGuest?.idNumber ?? '',
      nationality: existingGuest?.nationality ?? '',
    );
    await widget.bookingService.updateGuest(guest);

    // Auto-generate ref for new bookings, keep existing for edits
    final String bookingRef;
    if (_isEditing) {
      bookingRef = existingBooking!.bookingRef;
    } else {
      bookingRef = await widget.bookingRepo.getNextBookingRef();
    }

    final booking = Booking(
      id: existingBooking?.id ?? _uuid.v4(),
      bookingRef: bookingRef,
      guestId: guestId,
      roomId: _selectedRoomId!,
      checkInDate: _checkInDate!,
      checkOutDate: _checkOutDate!,
      status: _selectedStatus,
      numberOfGuests: int.tryParse(_guestsCountController.text.trim()) ?? 1,
      specialRequests: _specialRequestsController.text.trim(),
      source: _selectedSource,
      totalAmount: double.tryParse(_amountController.text.trim()) ?? 0.0,
      isPaid: _isPaid,
    );

    setState(() => _saving = true);
    try {
      if (existingBooking != null) {
        await widget.bookingService.updateBooking(booking);
      } else {
        await widget.bookingService.addReservation(booking);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Dialog Header ──────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.adminPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isEditing ? Icons.edit_calendar_rounded : Icons.calendar_month_rounded,
                          color: AppTheme.adminPrimary, size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _isEditing ? 'Edit Reservation' : 'Add Reservation',
                        style: AppTheme.serifHeadingLarge,
                      ),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 20), splashRadius: 18),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Booking Source ──────────────
                  _sectionLabel('BOOKING SOURCE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.enabledSources.map((source) {
                      final isSelected = _selectedSource == source;
                      final color = _colorForSource(source);
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSource = source),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.5),
                          ),
                          child: Text(
                            _labelForSource(source),
                            style: TextStyle(color: isSelected ? Colors.white : AppTheme.adminTextMuted, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ─── Guest Details ──────────────
                  _sectionLabel('GUEST DETAILS'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _guestNameController,
                    decoration: const InputDecoration(labelText: 'Guest Name', hintText: 'e.g. John Smith', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Guest name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', hintText: 'guest@email.com', prefixIcon: Icon(Icons.email_outlined)))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', hintText: '+1-555-0100', prefixIcon: Icon(Icons.phone_outlined)))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Booking Details ──────────────
                  _sectionLabel('BOOKING DETAILS'),
                  const SizedBox(height: 8),
                  // Date pickers FIRST (so room list can filter by date)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickDate(true),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Check-in Date',
                                hintText: 'Select date',
                                prefixIcon: Icon(Icons.login_rounded, color: AppTheme.success),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              controller: TextEditingController(text: _checkInDate != null ? dateFormat.format(_checkInDate!) : ''),
                              validator: (_) => _checkInDate == null ? 'Required' : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickDate(false),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Check-out Date',
                                hintText: 'Select date',
                                prefixIcon: Icon(Icons.logout_rounded, color: AppTheme.danger),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              controller: TextEditingController(text: _checkOutDate != null ? dateFormat.format(_checkOutDate!) : ''),
                              validator: (_) => _checkOutDate == null ? 'Required' : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRoomId,
                          decoration: const InputDecoration(labelText: 'Room', prefixIcon: Icon(Icons.meeting_room_outlined)),
                          items: _availableRooms.map((room) {
                            final underMaintenance = room.status == RoomStatus.maintenance;
                            return DropdownMenuItem(
                              value: room.id,
                              child: Text(
                                '${room.roomNumber} — ${room.typeLabel} (\$${room.pricePerNight.toInt()}/night)${underMaintenance ? ' ⚠️' : ''}',
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedRoomId = v),
                          validator: (v) => v == null ? 'Select a room' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _guestsCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Guests', hintText: '1', prefixIcon: Icon(Icons.group_outlined)),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v.trim()) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Total Amount ($_sym)',
                            hintText: 'e.g. 450.00',
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<BookingStatus>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.info_outline)),
                          items: BookingStatus.values.map((status) {
                            String label;
                            switch (status) {
                              case BookingStatus.pending: label = 'Pending'; break;
                              case BookingStatus.checkedIn: label = 'Checked In'; break;
                              case BookingStatus.checkedOut: label = 'Checked Out'; break;
                              case BookingStatus.cancelled: label = 'Cancelled'; break;
                            }
                            return DropdownMenuItem(value: status, child: Text(label));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedStatus = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _isPaid ? AppTheme.success.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _isPaid ? AppTheme.success.withOpacity(0.3) : Colors.transparent),
                    ),
                    child: CheckboxListTile(
                      title: const Text('Mark Accommodation as Paid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Guest has already paid the total booking amount upfront.', style: TextStyle(fontSize: 12)),
                      value: _isPaid,
                      activeColor: AppTheme.success,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      onChanged: (bool? value) {
                        setState(() {
                          _isPaid = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specialRequestsController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Special Requests', hintText: 'Any special requirements...', prefixIcon: Icon(Icons.note_outlined), alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 28),

                  // ─── Action Buttons ──────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: AppTheme.adminTextMuted)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _submit,
                        icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded, size: 18),
                        label: Text(_isEditing ? 'Save Changes' : 'Add Reservation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.adminPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }

  Color _colorForSource(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom: return const Color(0xFF003580);
      case BookingSource.airbnb:     return const Color(0xFFFF5A5F);
      case BookingSource.expedia:    return const Color(0xFF00355F);
      case BookingSource.direct:     return AppTheme.success;
      case BookingSource.other:      return AppTheme.warning;
    }
  }

  String _labelForSource(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom: return 'Booking.com';
      case BookingSource.airbnb:     return 'Airbnb';
      case BookingSource.expedia:    return 'Expedia';
      case BookingSource.direct:     return 'Direct';
      case BookingSource.other:      return 'Other';
    }
  }
}
