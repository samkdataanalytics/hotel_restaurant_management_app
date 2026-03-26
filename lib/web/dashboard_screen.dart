import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import 'widgets/skeleton.dart';
import '../models/check_in.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _bookingService = BookingService();
  final _timeFormat = DateFormat('hh:mm a');
  final _dateFormat = DateFormat('MMM dd, yyyy');

  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _recentCheckIns = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _bookingService.getDashboardStats();
      final checkIns = await _bookingService.getEnrichedCheckIns();

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
