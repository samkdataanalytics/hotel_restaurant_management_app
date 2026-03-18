import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/restaurant_order.dart';
import '../services/restaurant_service.dart';

const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;
const _kBlue = AppTheme.statusBlue;
const _kGreen = AppTheme.statusGreen;
const _kPurple = AppTheme.statusPurple;

class RestaurantAnalyticsScreen extends StatefulWidget {
  const RestaurantAnalyticsScreen({super.key});

  @override
  State<RestaurantAnalyticsScreen> createState() =>
      _RestaurantAnalyticsScreenState();
}

class _RestaurantAnalyticsScreenState
    extends State<RestaurantAnalyticsScreen> {
  final _service = RestaurantService();
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  bool _isLoading = true;

  // KPIs
  double _todayRevenue = 0;
  double _weekRevenue = 0;
  double _monthRevenue = 0;
  double _aov = 0;
  double _cancellationRate = 0;
  int _totalOrders = 0;
  int _todayCovers = 0; // number of dine-in orders today (proxy for covers)
  double _totalRefundedAmount = 0; // gross refund value across all orders
  int _refundedOrdersCount = 0;

  // Revenue bar chart
  List<double> _last7Rev = List.filled(7, 0);
  List<String> _last7Labels = [];

  // Order type mix
  int _dineInCount = 0;
  int _takeawayCount = 0;

  // Peak hours
  List<int> _peakHours = List.filled(24, 0);

  // Top items
  List<MapEntry<String, double>> _topItems = [];
  Map<String, String> _itemNames = {};
  Map<String, int> _itemCounts = {};

  // Food cost
  List<Map<String, dynamic>> _foodCostData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allOrders = await _service.getOrders();
    final valid = allOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();

    final now = DateTime.now();

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final todayOrders =
        valid.where((o) => sameDay(o.createdAt, now)).toList();
    final weekOrders =
        valid.where((o) => now.difference(o.createdAt).inDays < 7).toList();
    final monthOrders = valid
        .where((o) =>
            o.createdAt.month == now.month &&
            o.createdAt.year == now.year)
        .toList();

    _todayRevenue = todayOrders.fold(0.0, (s, o) => s + o.totalAmount);
    _weekRevenue = weekOrders.fold(0.0, (s, o) => s + o.totalAmount);
    _monthRevenue = monthOrders.fold(0.0, (s, o) => s + o.totalAmount);
    _totalOrders = valid.length;
    _aov = valid.isNotEmpty
        ? valid.fold(0.0, (s, o) => s + o.totalAmount) / valid.length
        : 0;
    _cancellationRate = allOrders.isNotEmpty
        ? allOrders
                .where((o) => o.status == OrderStatus.cancelled)
                .length /
            allOrders.length *
            100
        : 0;
    _todayCovers = todayOrders
        .where((o) => o.type == OrderType.dineIn)
        .length;

    // Last 7 days bar chart
    _last7Rev = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return valid
          .where((o) => sameDay(o.createdAt, day))
          .fold(0.0, (s, o) => s + o.totalAmount);
    });
    _last7Labels = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DateFormat('EEE').format(day);
    });

    // Order type mix
    _dineInCount = valid.where((o) => o.type == OrderType.dineIn).length;
    _takeawayCount = valid.where((o) => o.type == OrderType.takeaway).length;

    // Peak hours (0-23)
    _peakHours = List.filled(24, 0);
    for (final o in valid) {
      _peakHours[o.createdAt.hour]++;
    }

    // Refund totals (across all non-cancelled orders)
    _totalRefundedAmount = 0;
    _refundedOrdersCount = 0;
    for (final o in valid) {
      final refundedInOrder = o.items.fold(
          0.0, (s, i) => s + i.menuItem.price * i.refundedQuantity);
      if (refundedInOrder > 0) {
        _totalRefundedAmount += refundedInOrder;
        _refundedOrdersCount++;
      }
    }

    // Top selling items by net revenue (after refunds, using activeQuantity)
    final itemRev = <String, double>{};
    final itemCnt = <String, int>{};
    final itemNames = <String, String>{};
    for (final o in valid) {
      for (final item in o.items) {
        final qty = item.activeQuantity;
        if (qty <= 0) continue; // fully refunded — exclude entirely
        itemRev[item.menuItem.id] =
            (itemRev[item.menuItem.id] ?? 0) + item.subtotal;
        itemCnt[item.menuItem.id] =
            (itemCnt[item.menuItem.id] ?? 0) + qty;
        itemNames[item.menuItem.id] = item.menuItem.name;
      }
    }
    _topItems = (itemRev.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    _itemNames = itemNames;
    _itemCounts = itemCnt;

    // Food cost % per menu item
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
    foodCostList.sort(
        (a, b) => (b['costPct'] as double).compareTo(a['costPct'] as double));
    _foodCostData = foodCostList;

    if (mounted) setState(() => _isLoading = false);
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
          Text('$_totalOrders total orders',
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

  // ─── KPI Row ─────────────────────────────────────────

  Widget _buildKpiRow() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: 180,
          child: _kpiCard("Today's Revenue", _currency.format(_todayRevenue),
              Icons.today_rounded, _kGreen),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard("This Week", _currency.format(_weekRevenue),
              Icons.date_range_rounded, _kBlue),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard("This Month", _currency.format(_monthRevenue),
              Icons.calendar_month_rounded, _kOrange),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard("Avg Order Value", _currency.format(_aov),
              Icons.show_chart_rounded, _kPurple),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard(
              "Cancel Rate",
              '${_cancellationRate.toStringAsFixed(1)}%',
              Icons.cancel_outlined,
              _cancellationRate > 10 ? Colors.red : _kGreen,
              subtitle: _cancellationRate > 10 ? '↑ High' : '↓ Low'),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard("Today's Covers", '$_todayCovers dine-ins',
              Icons.people_rounded, Colors.teal),
        ),
        SizedBox(
          width: 180,
          child: _kpiCard(
              "Total Refunds",
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
    final maxY = _last7Rev.fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY > 0 ? maxY * 1.3 : 100.0;
    final allZero = maxY == 0;

    return _card(
      title: 'Revenue — Last 7 Days',
      icon: Icons.bar_chart_rounded,
      height: 240,
      child: allZero
          ? _emptyChart()
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barGroups: List.generate(
                  7,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _last7Rev[i],
                        color: i == 6
                            ? _kOrange
                            : _kOrange.withOpacity(0.4),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
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
                        '\$${value.toInt()}',
                        style: const TextStyle(
                            fontSize: 9, color: Colors.black38),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _last7Labels.length) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _last7Labels[idx],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: idx == 6
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: idx == 6
                                  ? _kOrange
                                  : Colors.black54,
                            ),
                          ),
                        );
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

  Widget _orderTypePie() {
    final total = _dineInCount + _takeawayCount;
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
                        PieChartSectionData(
                          value: _dineInCount.toDouble(),
                          color: _kOrange,
                          title:
                              '${(_dineInCount * 100 / total).round()}%',
                          radius: 70,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: _takeawayCount.toDouble(),
                          color: _kBlue,
                          title:
                              '${(_takeawayCount * 100 / total).round()}%',
                          radius: 70,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legend(_kOrange, 'Dine-in ($_dineInCount)'),
                    const SizedBox(width: 20),
                    _legend(_kBlue, 'Takeaway ($_takeawayCount)'),
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
