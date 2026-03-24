import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/booking.dart';
import '../models/room.dart';
import '../models/expense.dart';
import '../services/booking_service.dart';

class FinancialsScreen extends StatefulWidget {
  const FinancialsScreen({super.key});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen> {
  final _bookingService = BookingService();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _shortDateFormat = DateFormat('MMM dd');
  String get _sym => Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';

  List<Map<String, dynamic>> _enrichedBookings = [];
  List<Room> _rooms = [];
  List<Expense> _cachedExpenses = [];
  bool _isLoading = true;

  late DateTimeRange _dateRange;
  Set<BookingSource> _selectedSources = BookingSource.values.toSet();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to the current month
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bookings = await _bookingService.getEnrichedBookings();
      final rooms = await _bookingService.getAllRooms();
      final expenses = await _bookingService.getAllExpenses();
      if (!mounted) return;
      setState(() {
        _enrichedBookings = bookings;
        _rooms = rooms;
        _cachedExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load financials: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.adminPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  void _toggleSource(BookingSource source) {
    setState(() {
      if (_selectedSources.contains(source)) {
        if (_selectedSources.length > 1) {
          _selectedSources.remove(source);
        }
      } else {
        _selectedSources.add(source);
      }
    });
  }

  /// Get active bookings for a specific day
  List<Booking> _getBookingsForDay(DateTime day, {bool filterSource = true}) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return _enrichedBookings.map((d) => d['booking'] as Booking).where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (filterSource && !_selectedSources.contains(b.source)) return false;
      final checkIn = DateTime(b.checkInDate.year, b.checkInDate.month, b.checkInDate.day);
      final checkOut = DateTime(b.checkOutDate.year, b.checkOutDate.month, b.checkOutDate.day);
      return checkIn.isBefore(dayEnd) && checkOut.isAfter(dayStart);
    }).toList();
  }

  /// Get the allocated expense amount for a specific day
  double _getExpenseAmountForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    double dailyTotal = 0.0;
    for (final e in _cachedExpenses) {
      if (e.endDate != null) {
        final expStart = DateTime(e.date.year, e.date.month, e.date.day);
        final expEnd = DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day);
        
        // If day is within the expense period (inclusive)
        if (!dayStart.isBefore(expStart) && !dayStart.isAfter(expEnd)) {
          final totalDays = expEnd.difference(expStart).inDays + 1;
          dailyTotal += (e.amount / totalDays);
        }
      } else {
        if (!e.date.isBefore(dayStart) && e.date.isBefore(dayEnd)) {
          dailyTotal += e.amount;
        }
      }
    }
    return dailyTotal;
  }

  Color _sourceColor(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom:
        return Colors.blue.shade600;
      case BookingSource.airbnb:
        return Colors.red.shade500;
      case BookingSource.direct:
        return Colors.green.shade600;
      case BookingSource.other:
        return Colors.orange.shade500;
    }
  }

  String _sourceLabel(BookingSource source) {
    switch (source) {
      case BookingSource.bookingCom:
        return 'Booking.com';
      case BookingSource.airbnb:
        return 'Airbnb';
      case BookingSource.direct:
        return 'Direct';
      case BookingSource.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    double materializedRevenue = 0;
    double futureRevenue = 0;
    double potentialRevenue = 0;
    double totalExpenses = 0;
    int roomsToFill = 0;

    final days = <DateTime>[];
    for (int i = 0; i <= _dateRange.end.difference(_dateRange.start).inDays; i++) {
      days.add(_dateRange.start.add(Duration(days: i)));
    }

    final List<Map<String, dynamic>> dailyStats = [];

    for (final day in days) {
      final isFutureDay = day.isAfter(today);
      final dayBookings = _getBookingsForDay(day, filterSource: true);
      final double dayExpenseTotal = _getExpenseAmountForDay(day);
      
      double dayRevenue = 0;
      
      Map<BookingSource, double> sourceRevenues = {
        for (var s in BookingSource.values) s: 0.0
      };

      for (final b in dayBookings) {
        if (b.nights > 0) {
          final dailyRate = b.totalAmount / b.nights;
          dayRevenue += dailyRate;
          sourceRevenues[b.source] = (sourceRevenues[b.source] ?? 0) + dailyRate;
        }
      }

      if (isFutureDay) {
        futureRevenue += dayRevenue;

        // Calculate potential revenue (checking ALL bookings to know if room is occupied)
        final allBookingsOnDay = _getBookingsForDay(day, filterSource: false);
        for (final room in _rooms) {
          if (room.isUnderMaintenanceOn(day)) continue;

          bool isBooked = allBookingsOnDay.any((b) => b.roomId == room.id);
          if (!isBooked) {
            potentialRevenue += room.pricePerNight;
            roomsToFill++;
          }
        }
      } else {
        materializedRevenue += dayRevenue;
        totalExpenses += dayExpenseTotal;
      }

      dailyStats.add({
        'date': day,
        'activeBookings': dayBookings.length,
        'revenue': dayRevenue,
        'expenses': dayExpenseTotal,
        'netProfit': dayRevenue - dayExpenseTotal,
        'sourceRevenues': sourceRevenues,
      });
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Filters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financials Dashboard', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Monitor past, present, and potential future revenues.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text('${_dateFormat.format(_dateRange.start)} — ${_dateFormat.format(_dateRange.end)}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.adminPrimary,
                    side: BorderSide(color: AppTheme.adminPrimary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Advanced Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Gross Revenue',
                    subtitle: 'Up to today',
                    value: _fmtAmt(materializedRevenue),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Costs',
                    subtitle: 'Room expenses up to today',
                    value: _fmtAmt(totalExpenses),
                    icon: Icons.money_off_csred_rounded,
                    color: AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Net Profit',
                    subtitle: 'Revenue minus costs',
                    value: _fmtAmt(materializedRevenue - totalExpenses),
                    icon: Icons.payments_rounded,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Future & Potential',
                    subtitle: '+ ${_fmtAmt(potentialRevenue)} possible',
                    value: _fmtAmt(futureRevenue),
                    icon: Icons.event_available_rounded,
                    color: AppTheme.adminPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Source Legends / Filters
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Text('Filter Platforms:', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.adminTextMuted)),
                  const SizedBox(width: 16),
                  ...BookingSource.values.map((source) {
                    final isSelected = _selectedSources.contains(source);
                    final color = _sourceColor(source);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Text(_sourceLabel(source)),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        selectedColor: color,
                        side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
                        onSelected: (_) => _toggleSource(source),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Charts
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Revenue by Source', style: AppTheme.dmSerif(fontSize: 16)),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 300,
                            child: _buildRevenueChart(days, dailyStats),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Reservations', style: AppTheme.dmSerif(fontSize: 16)),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 300,
                            child: _buildBookingsLineChart(days, dailyStats),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Data Table
            Text('Daily Breakdown', style: AppTheme.dmSerif(fontSize: 18)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('DATE', style: _tableHeaderStyle())),
                          Expanded(flex: 2, child: Text('ACTIVE BOOKINGS', style: _tableHeaderStyle())),
                          Expanded(
                            flex: 2, 
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('REVENUE', style: _tableHeaderStyle()),
                            ),
                          ),
                          Expanded(
                            flex: 2, 
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('COSTS', style: _tableHeaderStyle()),
                            ),
                          ),
                          Expanded(
                            flex: 2, 
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('NET PROFIT', style: _tableHeaderStyle()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...dailyStats.reversed.map((stat) {
                      final date = stat['date'] as DateTime;
                      final activeBookings = stat['activeBookings'] as int;
                      final revenue = stat['revenue'] as double;
                      final expenses = stat['expenses'] as double;
                      final profit = stat['netProfit'] as double;
                      final isToday = date.isAtSameMomentAs(today);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: isToday ? AppTheme.adminPrimary.withOpacity(0.05) : Colors.white,
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Text(
                                    _dateFormat.format(date),
                                    style: TextStyle(
                                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                      color: isToday ? AppTheme.adminPrimary : Colors.black87,
                                    ),
                                  ),
                                  if (isToday)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppTheme.adminPrimary, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                activeBookings.toString(),
                                style: _numStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _fmtAmt(revenue, decimals: true),
                                  style: _numStyle(
                                    color: revenue > 0 ? AppTheme.success : AppTheme.adminTextMuted,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _fmtAmt(expenses, decimals: true),
                                  style: _numStyle(
                                    color: expenses > 0 ? AppTheme.danger : AppTheme.adminTextMuted,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  profit < 0
                                      ? '-${_fmtAmt(profit.abs(), decimals: true)}'
                                      : _fmtAmt(profit, decimals: true),
                                  style: _numStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: profit > 0 ? AppTheme.success : (profit < 0 ? AppTheme.danger : AppTheme.adminTextMuted),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<DateTime> days, List<Map<String, dynamic>> dailyStats) {
    if (days.isEmpty) return const SizedBox.shrink();
    
    // Find max value for Y-axis scaling
    double maxRevenue = 0;
    for (final stat in dailyStats) {
      if (stat['revenue'] > maxRevenue) maxRevenue = stat['revenue'];
    }
    // Add some padding to top
    maxRevenue = maxRevenue < 100 ? 100 : maxRevenue * 1.2;

    int dateInterval = (days.length / 7).ceil();
    if (dateInterval == 0) dateInterval = 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRevenue,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${_shortDateFormat.format(days[group.x.toInt()])}\n${_fmtAmt(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= days.length) return const SizedBox.shrink();
                if (index % dateInterval != 0 && index != days.length - 1 && index != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortDateFormat.format(days[index]),
                    style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxRevenue) return const SizedBox.shrink();
                return Text(
                  _fmtAmt(value),
                  style: TextStyle(
                    color: AppTheme.adminTextMuted,
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue > 0 ? maxRevenue / 4 : 50,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: dailyStats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final Map<BookingSource, double> sources = stat['sourceRevenues'];
          
          double currentY = 0;
          List<BarChartRodStackItem> stackItems = [];
          
          // Order defined by _selectedSources or enum order to maintain consistent stacking
          for (final source in BookingSource.values) {
            if (!_selectedSources.contains(source)) continue;
            final val = sources[source] ?? 0.0;
            if (val > 0) {
              stackItems.add(BarChartRodStackItem(currentY, currentY + val, _sourceColor(source)));
              currentY += val;
            }
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: currentY,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                rodStackItems: stackItems,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingsLineChart(List<DateTime> days, List<Map<String, dynamic>> dailyStats) {
    if (days.isEmpty) return const SizedBox.shrink();

    double maxBookings = 0;
    List<FlSpot> spots = [];
    
    for (int i = 0; i < dailyStats.length; i++) {
      final stat = dailyStats[i];
      final double val = (stat['activeBookings'] as int).toDouble();
      if (val > maxBookings) maxBookings = val;
      spots.add(FlSpot(i.toDouble(), val));
    }
    
    maxBookings = maxBookings < 5 ? 5 : maxBookings + 2;
    int dateInterval = (days.length / 5).ceil();
    if (dateInterval == 0) dateInterval = 1;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxBookings,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.adminPrimary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.adminPrimary.withOpacity(0.1),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= days.length) return const SizedBox.shrink();
                if (index % dateInterval != 0 && index != days.length - 1 && index != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _shortDateFormat.format(days[index]),
                    style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == maxBookings) return const SizedBox.shrink();
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppTheme.adminTextMuted,
      letterSpacing: 1.2,
    );
  }

  /// Formats a monetary amount with thousand separators and the property currency symbol.
  /// [decimals] true → two decimal places (table rows); false → whole number (KPI cards).
  String _fmtAmt(double amount, {bool decimals = false}) {
    final fmt = NumberFormat(decimals ? '#,##0.00' : '#,##0');
    return '$_sym${fmt.format(amount)}';
  }

  /// Text style for all numeric values — enables tabular (fixed-width) figures
  /// so digits align perfectly in columns regardless of their value.
  TextStyle _numStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value,
                        style: _numStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.adminTextMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
