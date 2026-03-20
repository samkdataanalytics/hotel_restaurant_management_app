import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_theme.dart';
import '../models/check_in.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/booking.dart';
import '../models/expense.dart';
import '../services/booking_service.dart';
import 'package:provider/provider.dart';
import '../providers/hotel_session.dart';
import '../services/invoice_service.dart';
import 'guest_responses_dialog.dart';

class CheckinsScreen extends StatefulWidget {
  const CheckinsScreen({super.key});

  @override
  State<CheckinsScreen> createState() => _CheckinsScreenState();
}

class _CheckinsScreenState extends State<CheckinsScreen> {
  final _bookingService = BookingService();
  final _invoiceService = InvoiceService();
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
    final checkIns = await _bookingService.getEnrichedCheckIns();
    final bookings = await _bookingService.getEnrichedBookings();

    if (!mounted) return;
    setState(() {
      _allCheckIns = checkIns;
      _filteredCheckIns = checkIns;
      _allBookings = bookings;
      _filteredBookings = bookings;
      _isLoading = false;
    });
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
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
                _tabButton('Check-ins', 'checkins',
                    '${_filteredCheckIns.length}'),
                const SizedBox(width: 8),
                _tabButton(
                    'All Bookings', 'bookings', '${_filteredBookings.length}'),
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

    return SizedBox(
      width: double.infinity,
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

    return SizedBox(
      width: double.infinity,
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
    Color color;
    switch (status) {
      case BookingStatus.pending:
        color = AppTheme.warning;
        break;
      case BookingStatus.checkedIn:
        color = AppTheme.success;
        break;
      case BookingStatus.checkedOut:
        color = AppTheme.adminTextMuted;
        break;
      case BookingStatus.cancelled:
        color = AppTheme.danger;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
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
        await _bookingService.updateBooking(updated);
        _loadData();
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
        await _bookingService.updateBooking(updated);
        _loadData();
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
    final url = '$baseUrl/#/guest-registration?ref=${booking.bookingRef}';

    if (!booking.isQrGenerated) {
      final updated = booking.copyWith(isQrGenerated: true);
      await _bookingService.updateBooking(updated);
      _loadData();
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Guest Registration QR: ${booking.bookingRef}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ask the guest to scan this QR code to securely fill out their information.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              SizedBox(
                width: 250,
                height: 250,
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(url, style: TextStyle(fontSize: 12, color: AppTheme.adminPrimary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printInvoice(Booking booking, Room room, Guest guest) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    // Fetch expenses just in time
    final expenses = await _bookingService.getAllExpenses();
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      final sym = Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';
      await _invoiceService.displayInvoicePdf(
        booking: booking,
        room: room,
        guest: guest,
        expenses: expenses,
        currencySymbol: sym,
      );
    }
  }
}
