import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/guest.dart';
import '../domain/entities/room.dart';
import '../domain/entities/booking.dart';
import '../services/booking_service.dart';
import '../services/restaurant_service.dart';
import '../services/invoice_service.dart';
import 'widgets/responsive_dialog.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hotel_session.dart';
import '../providers/service_providers.dart';
import '../domain/repositories/check_in_repository.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/expense_repository.dart';
import '../di/injection_container.dart';
import 'guest_responses_dialog.dart';

class CheckinsScreen extends ConsumerStatefulWidget {
  const CheckinsScreen({super.key});

  @override
  ConsumerState<CheckinsScreen> createState() => _CheckinsScreenState();
}

class _CheckinsScreenState extends ConsumerState<CheckinsScreen> {
  BookingService get _bookingService => ref.read(bookingServiceProvider);
  RestaurantService get _restaurantService => ref.read(restaurantServiceProvider);
  InvoiceService get _invoiceService => ref.read(invoiceServiceProvider);
  final _checkInRepo       = sl<CheckInRepository>();
  final _bookingRepo       = sl<BookingRepository>();
  final _orderRepo         = sl<OrderRepository>();
  final _expenseRepo       = sl<ExpenseRepository>();
  final _timeFormat = DateFormat('hh:mm a');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allCheckIns = [];
  List<Map<String, dynamic>> _filteredCheckIns = [];
  List<Map<String, dynamic>> _allBookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  bool _isLoading = true;
  String _viewMode = 'checkins'; // 'checkins' or 'bookings'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final checkIns = await _checkInRepo.getEnrichedCheckIns();
      final bookings = await _bookingRepo.getEnrichedBookings();
      if (!mounted) return;
      setState(() {
        _allCheckIns = checkIns;
        _filteredCheckIns = checkIns;
        _allBookings = bookings;
        _filteredBookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterData(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredCheckIns = _allCheckIns.where((data) {
        final guest = data['guest'] as Guest?;
        final room = data['room'] as Room?;
        return (guest?.fullName.toLowerCase().contains(q) ?? false) ||
            (room?.roomNumber.contains(q) ?? false);
      }).toList();

      _filteredBookings = _allBookings.where((data) {
        final guest = data['guest'] as Guest?;
        final booking = data['booking'] as Booking;
        return (guest?.fullName.toLowerCase().contains(q) ?? false) ||
            booking.bookingRef.toLowerCase().contains(q);
      }).toList();
    });
  }

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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Check-ins & Bookings',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search & tabs
            if (AppTheme.isMobile(context)) ...[
              TextField(
                controller: _searchController,
                onChanged: _filterData,
                decoration: InputDecoration(
                  hintText: 'Search guests, rooms...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tabButton('Check-ins', 'checkins', '${_filteredCheckIns.length}'),
                  const SizedBox(width: 8),
                  _tabButton('All Bookings', 'bookings', '${_filteredBookings.length}'),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterData,
                      decoration: InputDecoration(
                        hintText: 'Search by guest name, booking ref, or room...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _tabButton('Check-ins', 'checkins', '${_filteredCheckIns.length}'),
                  const SizedBox(width: 8),
                  _tabButton('All Bookings', 'bookings', '${_filteredBookings.length}'),
                ],
              ),
            const SizedBox(height: 24),

            // Content
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _viewMode == 'checkins'
                    ? _buildCheckInsTable()
                    : _buildBookingsTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, String mode, String count) {
    final isActive = _viewMode == mode;
    return Material(
      color: isActive ? AppTheme.adminPrimary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: isActive
                ? null
                : Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.adminTextMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.adminTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInsTable() {
    if (_filteredCheckIns.isEmpty) {
      return _emptyState('No check-ins found');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Guest')),
          DataColumn(label: Text('Room')),
          DataColumn(label: Text('Check-in Time')),
          DataColumn(label: Text('ID Verified')),
          DataColumn(label: Text('Key Issued')),
        ],
        rows: _filteredCheckIns.map((data) {
          final checkIn = data['checkIn'] as CheckIn;
          final guest = data['guest'] as Guest?;
          final room = data['room'] as Room?;

          return DataRow(cells: [
            DataCell(_guestCell(guest)),
            DataCell(_roomBadge(room?.roomNumber ?? '-')),
            DataCell(Text(
              '${_dateFormat.format(checkIn.checkInTime)} ${_timeFormat.format(checkIn.checkInTime)}',
            )),
            DataCell(_statusIcon(checkIn.idVerified)),
            DataCell(_statusIcon(checkIn.keyIssued)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildBookingsTable() {
    if (_filteredBookings.isEmpty) {
      return _emptyState('No bookings found');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Ref')),
          DataColumn(label: Text('Guest')),
          DataColumn(label: Text('Room')),
          DataColumn(label: Text('Check-in')),
          DataColumn(label: Text('Check-out')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('QR Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _filteredBookings.map((data) {
          final booking = data['booking'] as Booking;
          final guest = data['guest'] as Guest?;
          final room = data['room'] as Room?;

          return DataRow(cells: [
            DataCell(Text(
              booking.bookingRef,
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
            DataCell(_guestCell(guest)),
            DataCell(_roomBadge(room?.roomNumber ?? '-')),
            DataCell(Text(_dateFormat.format(booking.checkInDate))),
            DataCell(Text(_dateFormat.format(booking.checkOutDate))),
            DataCell(_statusBadge(booking.statusLabel, booking.status)),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (booking.isGuestFormSubmitted)
                  _guestFormBadge(booking, guest)
                else ...[
                  if (booking.isQrSent)
                    _qrSentBadge(booking)
                  else if (booking.isQrGenerated)
                    _markQrSentButton(booking)
                  else
                    const Text('-', style: TextStyle(color: Colors.black38)),
                ],
              ],
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.qr_code_2_rounded, size: 20, color: AppTheme.adminPrimary),
                  tooltip: 'Generate/Show QR Code',
                  onPressed: () => _showQrDialog(booking),
                  splashRadius: 20,
                ),
                if (guest != null && room != null)
                  IconButton(
                    icon: Icon(Icons.receipt_long_rounded, size: 20, color: AppTheme.adminTextMuted),
                    tooltip: 'Print Guest Folio',
                    onPressed: () => _printInvoice(booking, room, guest),
                    splashRadius: 20,
                  ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _guestCell(Guest? guest) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.adminPrimary.withValues(alpha: 0.1),
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
    );
  }

  Widget _roomBadge(String room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.adminPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        room,
        style: TextStyle(
          color: AppTheme.adminPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusIcon(bool value) {
    return Icon(
      value ? Icons.check_circle : Icons.cancel,
      color: value ? AppTheme.success : AppTheme.danger,
      size: 20,
    );
  }

  Widget _statusBadge(String label, BookingStatus status) {
    final Color color;
    final IconData icon;
    switch (status) {
      case BookingStatus.pending:
        color = AppTheme.warning;
        icon  = Icons.schedule_rounded;
        break;
      case BookingStatus.checkedIn:
        color = AppTheme.success;
        icon  = Icons.login_rounded;
        break;
      case BookingStatus.checkedOut:
        color = AppTheme.adminTextMuted;
        icon  = Icons.logout_rounded;
        break;
      case BookingStatus.cancelled:
        color = AppTheme.danger;
        icon  = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: AppTheme.adminTextMuted)),
        ],
      ),
    );
  }

  Widget _qrSentBadge(Booking booking) {
    return InkWell(
      onTap: () async {
        final updated = booking.copyWith(isQrSent: false);
        try { await _bookingService.updateBooking(updated); } catch (_) { return; }
        if (mounted) _loadData();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 12, color: AppTheme.warning),
            const SizedBox(width: 4),
            Text('QR Sent', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _markQrSentButton(Booking booking) {
    return InkWell(
      onTap: () async {
        final updated = booking.copyWith(isQrSent: true);
        try { await _bookingService.updateBooking(updated); } catch (_) { return; }
        if (mounted) _loadData();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.adminPrimary),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_rounded, size: 12, color: AppTheme.adminPrimary),
            const SizedBox(width: 4),
            Text('Mark Sent', style: TextStyle(color: AppTheme.adminPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
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
    final baseUrl = Uri.base.origin; // Gets e.g 'http://localhost:8080'
    final url = '$baseUrl/guest-registration?ref=${booking.bookingRef}';

    if (!booking.isQrGenerated) {
      final updated = booking.copyWith(isQrGenerated: true);
      try { await _bookingService.updateBooking(updated); } catch (_) {}
      if (mounted) _loadData();
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
                  'Ask the guest to scan this QR code to securely fill out their information.',
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

    try {
      final session = pkg_provider.Provider.of<HotelSession>(context, listen: false);
      _restaurantService.hotelId = session.hotelId;

      final expenses        = await _expenseRepo.getExpenses();
      final restaurantOrders = await _orderRepo.getChargedToRoomOrders(booking.id);

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }

      final settings = session.settings;
      await _invoiceService.displayInvoicePdf(
        booking:          booking,
        room:             room,
        guest:            guest,
        expenses:         expenses,
        restaurantOrders: restaurantOrders,
        currencySymbol:   settings?.currencySymbol ?? '\$',
        settings:         settings,
      );
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.pop(dialogContext!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load guest folio: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
