import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_service.dart';

const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;
const _kBlue = AppTheme.statusBlue;
const _kGreen = AppTheme.statusGreen;
const _kPurple = AppTheme.statusPurple;

// ─── Time scale ───────────────────────────────────────────────────────────────

enum _TimeScale { today, sevenDays, thirtyDays, ninetyDays, custom }

extension _TimeScaleX on _TimeScale {
  String get label => switch (this) {
    _TimeScale.today       => 'Today',
    _TimeScale.sevenDays   => '7 Days',
    _TimeScale.thirtyDays  => '30 Days',
    _TimeScale.ninetyDays  => '90 Days',
    _TimeScale.custom      => 'Custom',
  };

  String barTitle(DateTime start, DateTime end) => switch (this) {
    _TimeScale.today      => 'Revenue — Today (hourly)',
    _TimeScale.sevenDays  => 'Revenue — Last 7 Days',
    _TimeScale.thirtyDays => 'Revenue — Last 30 Days',
    _TimeScale.ninetyDays => 'Revenue — Last 90 Days (weekly)',
    _TimeScale.custom     =>
      'Revenue — ${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(end)}',
  };

  /// Start of the period relative to [now]. Not used for [custom].
  DateTime start(DateTime now) => switch (this) {
    _TimeScale.today       => DateTime(now.year, now.month, now.day),
    _TimeScale.sevenDays   => now.subtract(const Duration(days: 6)),
    _TimeScale.thirtyDays  => now.subtract(const Duration(days: 29)),
    _TimeScale.ninetyDays  => now.subtract(const Duration(days: 89)),
    _TimeScale.custom      => now, // overridden by _customStart
  };
}

class RestaurantAnalyticsScreen extends StatefulWidget {
  const RestaurantAnalyticsScreen({super.key});

  @override
  State<RestaurantAnalyticsScreen> createState() =>
      _RestaurantAnalyticsScreenState();
}

class _RestaurantAnalyticsScreenState
    extends State<RestaurantAnalyticsScreen> {
  final _service = RestaurantService();
  NumberFormat get _currency => NumberFormat.currency(
      symbol: Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);
  String get _sym => Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';

  bool _isLoading = true;
  _TimeScale _selectedScale = _TimeScale.sevenDays;
  DateTime? _customStart;
  DateTime? _customEnd;

  // KPIs (period-scoped)
  double _periodRevenue = 0;
  double _aov = 0;
  double _cancellationRate = 0;
  int _totalOrders = 0;
  int _periodCovers = 0;
  double _totalRefundedAmount = 0;
  int _refundedOrdersCount = 0;

  // Revenue bar chart (adapts to scale)
  List<double> _barData = [];
  List<String> _barLabels = [];

  // Order type mix (period-scoped)
  int _dineInCount = 0;
  int _takeawayCount = 0;
  int _deliveryCount = 0;

  // Delivery platform breakdown (period-scoped)
  int    _uberEatsCount   = 0;
  int    _pickMeCount     = 0;
  int    _otherCount      = 0;
  double _uberEatsRevenue = 0;
  double _pickMeRevenue   = 0;
  double _otherRevenue    = 0;

  // Peak hours (period-scoped)
  List<int> _peakHours = List.filled(24, 0);

  // Top items (period-scoped)
  List<MapEntry<String, double>> _topItems = [];
  Map<String, String> _itemNames = {};
  Map<String, int> _itemCounts = {};

  // Food cost (static — not period-dependent)
  List<Map<String, dynamic>> _foodCostData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allOrders = await _service.getOrders();
      final now = DateTime.now();

      // Resolve period boundaries
      final DateTime periodStart;
      final DateTime periodEnd;
      if (_selectedScale == _TimeScale.custom &&
          _customStart != null && _customEnd != null) {
        periodStart = DateTime(_customStart!.year, _customStart!.month, _customStart!.day);
        periodEnd   = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
      } else {
        periodStart = _selectedScale.start(now);
        periodEnd   = now;
      }

      bool sameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;

      // All non-cancelled orders in the selected period
      final valid = allOrders
          .where((o) =>
              o.status != OrderStatus.cancelled &&
              !o.createdAt.isBefore(periodStart) &&
              !o.createdAt.isAfter(periodEnd))
          .toList();

      // KPIs
      _periodRevenue = valid.fold(0.0, (s, o) => s + o.totalAmount);
      _totalOrders   = valid.length;
      _aov           = valid.isNotEmpty ? _periodRevenue / valid.length : 0;
      _cancellationRate = allOrders.isNotEmpty
          ? allOrders.where((o) => o.status == OrderStatus.cancelled).length /
                allOrders.length * 100
          : 0;
      _periodCovers = valid.where((o) => o.type == OrderType.dineIn).length;

      // Refunds
      _totalRefundedAmount = 0;
      _refundedOrdersCount = 0;
      for (final o in valid) {
        final refundedInOrder = o.items.fold(
            0.0, (s, i) => s + i.unitPrice * o.discountFactor * i.refundedQuantity);
        if (refundedInOrder > 0) {
          _totalRefundedAmount += refundedInOrder;
          _refundedOrdersCount++;
        }
      }

      // Bar chart — granularity depends on scale
      final spanDays = periodEnd.difference(periodStart).inDays + 1;
      switch (_selectedScale) {
        case _TimeScale.today:
          // Hourly buckets: 0–23
          _barData = List.generate(24, (h) =>
              valid.where((o) => o.createdAt.hour == h).fold(0.0, (s, o) => s + o.totalAmount));
          _barLabels = List.generate(24, (h) => '${h}h');

        case _TimeScale.sevenDays:
          _barData = List.generate(7, (i) {
            final day = now.subtract(Duration(days: 6 - i));
            return valid.where((o) => sameDay(o.createdAt, day)).fold(0.0, (s, o) => s + o.totalAmount);
          });
          _barLabels = List.generate(7, (i) =>
              DateFormat('EEE').format(now.subtract(Duration(days: 6 - i))));

        case _TimeScale.thirtyDays:
          _barData = List.generate(30, (i) {
            final day = now.subtract(Duration(days: 29 - i));
            return valid.where((o) => sameDay(o.createdAt, day)).fold(0.0, (s, o) => s + o.totalAmount);
          });
          _barLabels = List.generate(30, (i) {
            final day = now.subtract(Duration(days: 29 - i));
            return i % 5 == 0 ? DateFormat('MMM d').format(day) : '';
          });

        case _TimeScale.ninetyDays:
          // Group into 13 weekly buckets
          _barData = List.generate(13, (i) {
            final weekStart = now.subtract(Duration(days: (12 - i) * 7 + 6));
            final weekEnd   = now.subtract(Duration(days: (12 - i) * 7));
            return valid.where((o) =>
                !o.createdAt.isBefore(weekStart) && !o.createdAt.isAfter(weekEnd))
              .fold(0.0, (s, o) => s + o.totalAmount);
          });
          _barLabels = List.generate(13, (i) {
            final weekEnd = now.subtract(Duration(days: (12 - i) * 7));
            return DateFormat('MMM d').format(weekEnd);
          });

        case _TimeScale.custom:
          if (spanDays <= 1) {
            // Single day → hourly
            _barData = List.generate(24, (h) =>
                valid.where((o) => o.createdAt.hour == h).fold(0.0, (s, o) => s + o.totalAmount));
            _barLabels = List.generate(24, (h) => '${h}h');
          } else if (spanDays <= 31) {
            // Daily
            _barData = List.generate(spanDays, (i) {
              final day = periodStart.add(Duration(days: i));
              return valid.where((o) => sameDay(o.createdAt, day)).fold(0.0, (s, o) => s + o.totalAmount);
            });
            final labelEvery = spanDays > 14 ? 5 : 1;
            _barLabels = List.generate(spanDays, (i) {
              final day = periodStart.add(Duration(days: i));
              return i % labelEvery == 0 ? DateFormat('MMM d').format(day) : '';
            });
          } else {
            // Weekly
            final weeks = (spanDays / 7).ceil();
            _barData = List.generate(weeks, (i) {
              final wStart = periodStart.add(Duration(days: i * 7));
              final wEnd   = wStart.add(const Duration(days: 6));
              return valid.where((o) =>
                  !o.createdAt.isBefore(wStart) && !o.createdAt.isAfter(wEnd))
                .fold(0.0, (s, o) => s + o.totalAmount);
            });
            _barLabels = List.generate(weeks, (i) {
              final wStart = periodStart.add(Duration(days: i * 7));
              return DateFormat('MMM d').format(wStart);
            });
          }
      }

      // Order type mix
      _dineInCount   = valid.where((o) => o.type == OrderType.dineIn).length;
      _takeawayCount = valid.where((o) => o.type == OrderType.takeaway).length;
      _deliveryCount = valid.where((o) => o.type == OrderType.delivery).length;

      // Delivery platform breakdown
      final deliveryOrders = valid.where((o) => o.type == OrderType.delivery).toList();
      _uberEatsCount   = deliveryOrders.where((o) => o.deliveryPlatform == 'UberEats').length;
      _pickMeCount     = deliveryOrders.where((o) => o.deliveryPlatform == 'PickMe').length;
      _otherCount      = deliveryOrders.where((o) => o.deliveryPlatform == 'Other').length;
      _uberEatsRevenue = deliveryOrders.where((o) => o.deliveryPlatform == 'UberEats').fold(0.0, (s, o) => s + o.totalAmount);
      _pickMeRevenue   = deliveryOrders.where((o) => o.deliveryPlatform == 'PickMe').fold(0.0, (s, o) => s + o.totalAmount);
      _otherRevenue    = deliveryOrders.where((o) => o.deliveryPlatform == 'Other').fold(0.0, (s, o) => s + o.totalAmount);

      // Peak hours
      _peakHours = List.filled(24, 0);
      for (final o in valid) { _peakHours[o.createdAt.hour]++; }

      // Top selling items
      final itemRev   = <String, double>{};
      final itemCnt   = <String, int>{};
      final itemNames = <String, String>{};
      for (final o in valid) {
        for (final item in o.items) {
          final qty = item.activeQuantity;
          if (qty <= 0) continue;
          itemRev[item.menuItem.id]   = (itemRev[item.menuItem.id] ?? 0) + item.subtotal;
          itemCnt[item.menuItem.id]   = (itemCnt[item.menuItem.id] ?? 0) + qty;
          itemNames[item.menuItem.id] = item.menuItem.name;
        }
      }
      _topItems   = (itemRev.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
      _itemNames  = itemNames;
      _itemCounts = itemCnt;

      // Food cost — not period-dependent, load once
      if (_foodCostData.isEmpty) {
        final menuItems = await _service.getMenuItems();
        final foodCostList = <Map<String, dynamic>>[];
        for (final item in menuItems) {
          if (item.ingredients.isEmpty) continue;
          final cost = await _service.getCurrentCostForItem(item.id);
          if (cost != null && item.price > 0) {
            foodCostList.add({
              'name': item.name,
              'cost': cost,
              'price': item.price,
              'costPct': (cost / item.price * 100).clamp(0.0, 100.0),
            });
          }
        }
        foodCostList.sort((a, b) => (b['costPct'] as double).compareTo(a['costPct'] as double));
        _foodCostData = foodCostList;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load analytics: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildKpiRow(),
                      const SizedBox(height: 20),
                      _buildChartsRow(),
                      const SizedBox(height: 20),
                      _buildBottomRow(),
                      if (_deliveryCount > 0) ...[
                        const SizedBox(height: 20),
                        _buildDeliveryBreakdown(),
                      ],
                      if (_foodCostData.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildFoodCostSection(),
                      ],
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _kOrangeBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.analytics_rounded, color: _kOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Text('Restaurant Analytics',
              style: Theme.of(context).textTheme.displayMedium),
          const Spacer(),
          // ─── Time scale selector ───────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _TimeScale.values.map((scale) {
                final selected = _selectedScale == scale;
                return GestureDetector(
                  onTap: () async {
                    if (scale == _TimeScale.custom) {
                      await _pickDateRange();
                      return;
                    }
                    if (_selectedScale == scale) return;
                    setState(() { _selectedScale = scale; _foodCostData = []; });
                    _loadData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected
                          ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (scale == _TimeScale.custom)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Icon(Icons.calendar_month_rounded, size: 13,
                                color: selected ? _kOrange : Colors.black45),
                          ),
                        Text(
                          // Show chosen range when custom is active
                          selected && scale == _TimeScale.custom && _customStart != null
                              ? '${DateFormat('MMM d').format(_customStart!)} – ${DateFormat('MMM d').format(_customEnd!)}'
                              : scale.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? _kOrange : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 16),
          Text('$_totalOrders orders',
              style: const TextStyle(
                  color: Colors.black38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                side: const BorderSide(color: _kOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 6)),
              end: now,
            ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _kOrange,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _selectedScale = _TimeScale.custom;
      _customStart   = picked.start;
      _customEnd     = picked.end;
      _foodCostData  = [];
    });
    _loadData();
  }

  // ─── KPI Row ─────────────────────────────────────────

  Widget _buildKpiRow() {
    final periodLabel = (_selectedScale == _TimeScale.custom &&
            _customStart != null && _customEnd != null)
        ? '${DateFormat('MMM d').format(_customStart!)} – ${DateFormat('MMM d').format(_customEnd!)}'
        : _selectedScale.label;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: 180,
          child: _kpiCard('Revenue ($periodLabel)', _currency.format(_periodRevenue),
              Icons.payments_rounded, _kGreen),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard('Orders ($periodLabel)', '$_totalOrders',
              Icons.receipt_long_rounded, _kBlue),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard('Avg Order Value', _currency.format(_aov),
              Icons.show_chart_rounded, _kPurple),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard(
              'Cancel Rate',
              '${_cancellationRate.toStringAsFixed(1)}%',
              Icons.cancel_outlined,
              _cancellationRate > 10 ? Colors.red : _kGreen,
              subtitle: _cancellationRate > 10 ? '↑ High' : '↓ Low'),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard('Dine-in Covers', '$_periodCovers',
              Icons.people_rounded, Colors.teal),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard(
              'Refunds ($periodLabel)',
              _currency.format(_totalRefundedAmount),
              Icons.undo_rounded,
              Colors.deepOrange,
              subtitle: '$_refundedOrdersCount order(s) affected'),
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black38, fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Charts Row ──────────────────────────────────────

  Widget _buildChartsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _revenueBarChart()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _orderTypePie()),
      ],
    );
  }

  Widget _revenueBarChart() {
    final maxY = _barData.fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY > 0 ? maxY * 1.3 : 100.0;
    final allZero = maxY == 0;
    final count = _barData.length;
    // Bar width shrinks for larger datasets
    final barW = count <= 7 ? 22.0 : count <= 30 ? 10.0 : 14.0;

    return _card(
      title: _selectedScale.barTitle(
          _customStart ?? _selectedScale.start(DateTime.now()),
          _customEnd   ?? DateTime.now()),
      icon: Icons.bar_chart_rounded,
      height: 240,
      child: allZero
          ? _emptyChart()
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barGroups: List.generate(
                  count,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _barData[i],
                        color: i == count - 1
                            ? _kOrange
                            : _kOrange.withOpacity(0.4),
                        width: barW,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        '$_sym${value.toInt()}',
                        style: const TextStyle(fontSize: 9, color: Colors.black38),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _barLabels.length) return const SizedBox();
                        final label = _barLabels[idx];
                        if (label.isEmpty) return const SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: idx == count - 1 ? FontWeight.w800 : FontWeight.w400,
                              color: idx == count - 1 ? _kOrange : Colors.black45,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
    );
  }

  Widget _orderTypePie() {
    const _kDeliveryGreen = Color(0xFF06C167);
    final total = _dineInCount + _takeawayCount + _deliveryCount;
    return _card(
      title: 'Order Type Mix',
      icon: Icons.donut_large_rounded,
      height: 240,
      child: total == 0
          ? _emptyChart()
          : Column(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: [
                        if (_dineInCount > 0)
                          PieChartSectionData(
                            value: _dineInCount.toDouble(),
                            color: _kOrange,
                            title: '${(_dineInCount * 100 / total).round()}%',
                            radius: 70,
                            titleStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        if (_takeawayCount > 0)
                          PieChartSectionData(
                            value: _takeawayCount.toDouble(),
                            color: _kBlue,
                            title: '${(_takeawayCount * 100 / total).round()}%',
                            radius: 70,
                            titleStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        if (_deliveryCount > 0)
                          PieChartSectionData(
                            value: _deliveryCount.toDouble(),
                            color: _kDeliveryGreen,
                            title: '${(_deliveryCount * 100 / total).round()}%',
                            radius: 70,
                            titleStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                      ],
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (_dineInCount > 0)   _legend(_kOrange,        'Dine-in ($_dineInCount)'),
                    if (_takeawayCount > 0) _legend(_kBlue,          'Takeaway ($_takeawayCount)'),
                    if (_deliveryCount > 0) _legend(_kDeliveryGreen, 'Delivery ($_deliveryCount)'),
                  ],
                ),
              ],
            ),
    );
  }

  // ─── Bottom Row ──────────────────────────────────────

  Widget _buildBottomRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _topItemsTable()),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: _peakHoursChart()),
      ],
    );
  }

  Widget _topItemsTable() {
    return _card(
      title: 'Top Selling Items',
      icon: Icons.emoji_events_rounded,
      child: _topItems.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No sales data yet',
                    style: TextStyle(color: Colors.black38)),
              ),
            )
          : Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                        flex: 3,
                        child: _TH('Item')),
                    Expanded(child: _TH('Qty', center: true)),
                    Expanded(child: _TH('Revenue', right: true)),
                  ],
                ),
                const Divider(height: 16),
                ..._topItems.asMap().entries.map((e) {
                  final rank = e.key;
                  final itemId = e.value.key;
                  final revenue = e.value.value;
                  final rankColors = [
                    const Color(0xFFFFD700),
                    const Color(0xFFC0C0C0),
                    const Color(0xFFCD7F32),
                    Colors.black26,
                    Colors.black26,
                  ];
                  final rc = rankColors[rank];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: rc.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Center(
                            child: Text('${rank + 1}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: rc)),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            _itemNames[itemId] ?? itemId,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text('${_itemCounts[itemId] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ),
                        Expanded(
                          child: Text(_currency.format(revenue),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kOrange)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _peakHoursChart() {
    // Show hours 6 am – 11 pm (indices 6-23)
    const startHour = 6;
    const endHour = 23;
    final hours =
        List.generate(endHour - startHour + 1, (i) => i + startHour);
    final maxVal = hours.fold(0, (m, h) => _peakHours[h] > m ? _peakHours[h] : m);
    final maxY = maxVal > 0 ? maxVal.toDouble() * 1.3 : 5.0;

    return _card(
      title: 'Peak Hours  (orders per hour)',
      icon: Icons.schedule_rounded,
      height: 200,
      child: maxVal == 0
          ? _emptyChart()
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barGroups: hours.asMap().entries.map((e) {
                  final i = e.key;
                  final h = e.value;
                  final count = _peakHours[h];
                  final isPeak = count == maxVal && maxVal > 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: isPeak
                            ? _kOrange
                            : _kOrange.withOpacity(0.35),
                        width: 12,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= hours.length) {
                          return const SizedBox();
                        }
                        if (idx % 3 != 0) return const SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text('${hours[idx]}h',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.black38)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble() ||
                            value == 0) {
                          return const SizedBox();
                        }
                        return Text('${value.toInt()}',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black38));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
    );
  }

  // ─── Delivery Platform Breakdown ─────────────────────

  Widget _buildDeliveryBreakdown() {
    const _kUber   = Color(0xFF06C167);
    const _kPickMe = Color(0xFFFF6B35);
    const _kOther  = Color(0xFF6B7280);

    final platforms = [
      (
        label: 'UberEats',
        icon: Icons.delivery_dining_rounded,
        color: _kUber,
        count: _uberEatsCount,
        revenue: _uberEatsRevenue,
      ),
      (
        label: 'PickMe',
        icon: Icons.moped_rounded,
        color: _kPickMe,
        count: _pickMeCount,
        revenue: _pickMeRevenue,
      ),
      (
        label: 'Other',
        icon: Icons.storefront_rounded,
        color: _kOther,
        count: _otherCount,
        revenue: _otherRevenue,
      ),
    ];

    final maxRevenue = platforms.fold(0.0, (m, p) => p.revenue > m ? p.revenue : m);

    return _card(
      title: 'Delivery Platform Breakdown',
      icon: Icons.delivery_dining_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Row(
            children: platforms.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final isLast = i == platforms.length - 1;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.color.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(p.icon, color: p.color, size: 18),
                          const SizedBox(width: 6),
                          Text(p.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: p.color)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${p.count} orders',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 2),
                      Text(_currency.format(p.revenue),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: p.color)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Revenue bars
          ...platforms.where((p) => p.count > 0).map((p) {
            final frac = maxRevenue > 0 ? p.revenue / maxRevenue : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(p.label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        backgroundColor: Colors.grey.shade100,
                        color: p.color,
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    child: Text('${p.count}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: p.color)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Food Cost Section ───────────────────────────────

  Widget _buildFoodCostSection() {
    final avg = _foodCostData.fold(
            0.0, (s, d) => s + (d['costPct'] as double)) /
        _foodCostData.length;
    const benchmark = 30.0; // industry standard 28-35%
    final isGood = avg <= benchmark;

    return _card(
      title: 'Food Cost Analysis',
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isGood
                  ? const Color(0xFFF0FFF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isGood
                    ? _kGreen.withOpacity(0.3)
                    : _kOrange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isGood
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: isGood ? _kGreen : _kOrange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                      children: [
                        const TextSpan(text: 'Average food cost: '),
                        TextSpan(
                          text: '${avg.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isGood ? _kGreen : _kOrange,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '   •   Industry benchmark: $benchmark% (28–35%)',
                          style: TextStyle(
                              color: Colors.black38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Per-item table
          Row(
            children: const [
              Expanded(flex: 3, child: _TH('Menu Item')),
              Expanded(child: _TH('Cost', center: true)),
              Expanded(child: _TH('Price', center: true)),
              Expanded(flex: 2, child: _TH('Cost %', right: true)),
            ],
          ),
          const Divider(height: 14),
          ..._foodCostData.map((d) {
            final pct = d['costPct'] as double;
            final isHigh = pct > benchmark;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(d['name'] as String,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Text(_currency.format(d['cost']),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ),
                  Expanded(
                    child: Text(_currency.format(d['price']),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct / 100,
                              backgroundColor: Colors.grey.shade100,
                              color: isHigh ? Colors.red.shade400 : _kGreen,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44,
                          child: Text('${pct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isHigh
                                      ? Colors.red.shade400
                                      : _kGreen)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    double? height,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: _kOrangeBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: _kOrange, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          if (height != null)
            SizedBox(height: height, child: child)
          else
            child,
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _emptyChart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 36, color: Colors.black12),
          SizedBox(height: 8),
          Text('No data yet',
              style: TextStyle(color: Colors.black26, fontSize: 13)),
        ],
      ),
    );
  }
}

// Reusable table header cell
class _TH extends StatelessWidget {
  final String text;
  final bool center;
  final bool right;

  const _TH(this.text, {this.center = false, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: right
          ? TextAlign.end
          : center
              ? TextAlign.center
              : TextAlign.start,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
          letterSpacing: 0.5),
    );
  }
}
