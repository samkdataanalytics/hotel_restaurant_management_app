import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/restaurant_order.dart';
import '../app_theme.dart';
import '../models/restaurant_table.dart';
import '../services/restaurant_service.dart';

const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;

// ─── Data models for the two lists ──────────────────────────────────────────

class _CancelledRow {
  final RestaurantOrder order;
  final String tableLabel;
  _CancelledRow(this.order, this.tableLabel);
}

class _RefundRow {
  final RestaurantOrder order;
  final String itemName;
  final String itemEmoji;
  final double unitPrice;
  final int orderedQty;
  final int refundedQty;
  _RefundRow({
    required this.order,
    required this.itemName,
    required this.itemEmoji,
    required this.unitPrice,
    required this.orderedQty,
    required this.refundedQty,
  });
  double get refundAmount => unitPrice * refundedQty;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CancellationsRefundsScreen extends StatefulWidget {
  const CancellationsRefundsScreen({super.key});

  @override
  State<CancellationsRefundsScreen> createState() =>
      _CancellationsRefundsScreenState();
}

class _CancellationsRefundsScreenState
    extends State<CancellationsRefundsScreen>
    with SingleTickerProviderStateMixin {
  final _service = RestaurantService();
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateF = DateFormat('MMM d, HH:mm');

  bool _isLoading = true;
  late TabController _tabController;

  List<_CancelledRow> _cancelled = [];
  List<_RefundRow> _refunds = [];

  // Summary KPIs
  int _totalCancellations = 0;
  double _totalCancelledValue = 0;
  int _inventoryRestoredCount = 0;
  int _totalRefundLines = 0;
  double _totalRefundedValue = 0;
  int _ordersWithRefunds = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final orders = await _service.getOrders();
    final tables = await _service.getTables();

    String tableLabel(String? id) {
      if (id == null) return 'Takeaway';
      try {
        return 'Table ${tables.firstWhere((t) => t.id == id).tableNumber}';
      } catch (_) {
        return '—';
      }
    }

    // ── Cancelled orders
    final cancelledOrders = orders
        .where((o) => o.status == OrderStatus.cancelled)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _cancelled = cancelledOrders
        .map((o) => _CancelledRow(o, tableLabel(o.tableId)))
        .toList();

    _totalCancellations = cancelledOrders.length;
    _totalCancelledValue =
        cancelledOrders.fold(0.0, (s, o) => s + o.totalAmount);
    // totalAmount on a cancelled order = 0 (all items active qty = 0 after cancel)
    // so use gross: sum of (price * ordered qty) for display purposes
    _totalCancelledValue = cancelledOrders.fold(
        0.0,
        (s, o) => s +
            o.items.fold(
                0.0, (si, i) => si + i.menuItem.price * i.quantity));
    _inventoryRestoredCount =
        cancelledOrders.where((o) => o.inventoryRestored).length;

    // ── Refunded items (from non-cancelled, served orders)
    final refundRows = <_RefundRow>[];
    int ordersWithRef = 0;
    double totalRefVal = 0;

    for (final o in orders) {
      if (o.status == OrderStatus.cancelled) continue;
      bool hasRefund = false;
      for (final item in o.items) {
        if (item.refundedQuantity > 0) {
          refundRows.add(_RefundRow(
            order: o,
            itemName: item.menuItem.name,
            itemEmoji: item.menuItem.imageUrl.isNotEmpty
                ? item.menuItem.imageUrl
                : '🍽️',
            unitPrice: item.menuItem.price,
            orderedQty: item.quantity,
            refundedQty: item.refundedQuantity,
          ));
          totalRefVal += item.menuItem.price * item.refundedQuantity;
          hasRefund = true;
        }
      }
      if (hasRefund) ordersWithRef++;
    }

    refundRows.sort((a, b) => b.order.createdAt.compareTo(a.order.createdAt));

    _refunds = refundRows;
    _totalRefundLines = refundRows.length;
    _totalRefundedValue = totalRefVal;
    _ordersWithRefunds = ordersWithRef;

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoading) _buildKpiRow(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCancelledTab(),
                      _buildRefundsTab(),
                    ],
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
            child: const Icon(Icons.remove_circle_outline_rounded,
                color: _kOrange, size: 22),
          ),
          const SizedBox(width: 14),
          Text('Cancellations & Refunds',
              style: Theme.of(context).textTheme.displayMedium),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _load,
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

  Widget _buildKpiRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          _kpi('Cancellations', '$_totalCancellations',
              Icons.cancel_outlined, Colors.red.shade400),
          _kpiDivider(),
          _kpi('Cancelled Value', _currency.format(_totalCancelledValue),
              Icons.money_off_rounded, Colors.red.shade300),
          _kpiDivider(),
          _kpi('Inventory Restored',
              '$_inventoryRestoredCount / $_totalCancellations',
              Icons.inventory_2_outlined, Colors.teal),
          _kpiDivider(),
          _kpi('Refund Lines', '$_totalRefundLines',
              Icons.undo_rounded, _kOrange),
          _kpiDivider(),
          _kpi('Total Refunded', _currency.format(_totalRefundedValue),
              Icons.currency_exchange_rounded, Colors.deepOrange),
          _kpiDivider(),
          _kpi('Orders Affected', '$_ordersWithRefunds',
              Icons.receipt_long_outlined, _kOrange),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black38,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiDivider() => Container(
        height: 36,
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: Colors.grey.shade200,
      );

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const Divider(height: 1),
          TabBar(
            controller: _tabController,
            labelColor: _kOrange,
            unselectedLabelColor: Colors.black45,
            indicatorColor: _kOrange,
            tabs: [
              Tab(
                icon: const Icon(Icons.cancel_outlined, size: 16),
                text: 'Cancelled Orders ($_totalCancellations)',
              ),
              Tab(
                icon: const Icon(Icons.undo_rounded, size: 16),
                text: 'Refunded Items ($_totalRefundLines)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Cancelled Orders Tab ────────────────────────────

  Widget _buildCancelledTab() {
    if (_cancelled.isEmpty) return _emptyState('No cancelled orders');
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _cancelled.length,
      itemBuilder: (_, i) => _cancelledCard(_cancelled[i]),
    );
  }

  Widget _cancelledCard(_CancelledRow row) {
    final o = row.order;
    final grossValue =
        o.items.fold(0.0, (s, i) => s + i.menuItem.price * i.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _badge('#${o.orderNumber}', Colors.red.shade400,
                  Colors.red.shade50),
              const SizedBox(width: 8),
              _badge(row.tableLabel, Colors.grey, Colors.grey.shade100),
              const SizedBox(width: 8),
              _badge(
                  o.type == OrderType.dineIn ? 'Dine-in' : 'Takeaway',
                  Colors.blueGrey,
                  Colors.blueGrey.shade50),
              const Spacer(),
              // Inventory badge
              _inventoryBadge(o.inventoryRestored),
              const SizedBox(width: 12),
              Text(_dateF.format(o.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 12),
          // Items list
          ...o.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                        item.menuItem.imageUrl.isNotEmpty
                            ? item.menuItem.imageUrl
                            : '🍽️',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.menuItem.name}  ×${item.quantity}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.lineThrough),
                      ),
                    ),
                    Text(
                      _currency.format(item.menuItem.price * item.quantity),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          decoration: TextDecoration.lineThrough),
                    ),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            children: [
              if (o.paymentStatus == PaymentStatus.chargedToRoom)
                _badge('Room charge reversed', Colors.amber.shade700,
                    Colors.amber.shade50),
              const Spacer(),
              Text('Gross value: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              Text(_currency.format(grossValue),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inventoryBadge(bool restored) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: restored
            ? const Color(0xFFF0FFF4)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: restored
                ? Colors.green.shade200
                : Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            restored
                ? Icons.inventory_2_outlined
                : Icons.warning_amber_rounded,
            size: 12,
            color: restored ? Colors.green.shade600 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            restored ? 'Inventory restored' : 'Inventory NOT restored',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: restored
                    ? Colors.green.shade700
                    : Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  // ─── Refunded Items Tab ──────────────────────────────

  Widget _buildRefundsTab() {
    if (_refunds.isEmpty) return _emptyState('No refunded items');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Policy note
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Refunds are processed on served orders. '
                  'Inventory is not restored as the food has been prepared and consumed.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),
        // Refund rows
        ..._refunds.map((r) => _refundCard(r)),
      ],
    );
  }

  Widget _refundCard(_RefundRow r) {
    final isPartial = r.refundedQty < r.orderedQty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kOrangeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(r.itemEmoji,
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          // Name + order ref
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.itemName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Order #${r.order.orderNumber}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          // Qty detail
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12),
                    children: [
                      TextSpan(
                        text: '${r.refundedQty}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.deepOrange),
                      ),
                      TextSpan(
                        text: ' / ${r.orderedQty} refunded',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPartial
                        ? Colors.orange.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPartial ? 'Partial' : 'Full',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPartial
                            ? Colors.orange.shade700
                            : Colors.red.shade500),
                  ),
                ),
              ],
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _dateF.format(r.order.createdAt),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ),
          // Refund amount
          SizedBox(
            width: 80,
            child: Text(
              _currency.format(r.refundAmount),
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.deepOrange.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  Widget _badge(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message,
              style:
                  const TextStyle(color: Colors.black38, fontSize: 15)),
        ],
      ),
    );
  }
}
