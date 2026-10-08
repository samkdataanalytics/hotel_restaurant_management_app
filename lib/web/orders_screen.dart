import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import '../domain/entities/restaurant_order.dart';
import '../domain/entities/staff_permission.dart';
import '../providers/hotel_session.dart';
import '../domain/entities/restaurant_table.dart';
import '../app_theme.dart';
import '../services/restaurant_service.dart';
import '../providers/service_providers.dart';
import '../di/injection_container.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/restaurant_table_repository.dart';
import 'restaurant_invoice_dialog.dart';

const _kAccent = AppTheme.restaurantAccent;
const _kAccentBg = AppTheme.restaurantAccentBg;

enum _DateFilter { today, week, all }

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  RestaurantService get _service => ref.read(restaurantServiceProvider);
  final _orderRepo = sl<OrderRepository>();
  final _tableRepo = sl<RestaurantTableRepository>();
  NumberFormat get _currency => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);

  List<RestaurantOrder> _orders = [];
  List<RestaurantTable> _tables = [];
  bool _isLoading = true;
  _DateFilter _dateFilter = _DateFilter.today;
  OrderStatus? _statusFilter;
  
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _orderRepo.getOrders();
      final tables = await _tableRepo.getTables();
      if (!mounted) return;
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _orders = orders;
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<RestaurantOrder> get _filtered {
    final now = DateTime.now();
    return _orders.where((o) {
      bool dateOk = true;
      if (_dateFilter == _DateFilter.today) {
        dateOk = DateUtils.isSameDay(o.createdAt, now);
      } else if (_dateFilter == _DateFilter.week) {
        dateOk = now.difference(o.createdAt).inDays < 7;
      }
      final statusOk = _statusFilter == null || o.status == _statusFilter;
      final searchOk = _searchQuery.isEmpty || 
          o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase());
      return dateOk && statusOk && searchOk;
    }).toList();
  }

  String _tableName(String? id) {
    if (id == null) return '—';
    try {
      return 'T${_tables.firstWhere((t) => t.id == id).tableNumber}';
    } catch (_) {
      return '—';
    }
  }

  // ─── Actions ────────────────────────────────────────

  Future<void> _cancelOrder(RestaurantOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('Cancel Order'),
          ],
        ),
        content: Text(
          order.status == OrderStatus.pending
              ? 'Cancel order #${order.orderNumber}?\n\nIngredients will be returned to inventory (order not yet started).'
              : 'Cancel order #${order.orderNumber}?\n\nInventory will NOT be restored — ingredients are already in preparation.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service.cancelOrder(order.id);
    if (!mounted) return;
    final wasRestored = order.status == OrderStatus.pending;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasRestored
            ? 'Order #${order.orderNumber} cancelled. Inventory restored.'
            : 'Order #${order.orderNumber} cancelled. Inventory not restored (in preparation).'),
        backgroundColor: Colors.red.shade600,
      ),
    );
    _load();
  }

  Future<void> _showRefundDialog(RestaurantOrder order) async {
    final refundable = order.items.where((i) => !i.isFullyRefunded).toList();
    if (refundable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All items have already been refunded.')),
      );
      return;
    }

    // Map from itemId → how many units to refund (starts at 0)
    final refundQtys = {for (final i in refundable) i.id: 0};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final totalRefund = refundable.fold(0.0, (sum, item) {
            return sum + item.unitPrice * order.discountFactor * (refundQtys[item.id] ?? 0);
          });
          final anySelected = refundQtys.values.any((q) => q > 0);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.undo_rounded, color: _kAccent, size: 20),
                SizedBox(width: 8),
                Text('Refund Items'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose how many units to refund from #${order.orderNumber}:',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  ...refundable.map((item) {
                    final qty = refundQtys[item.id] ?? 0;
                    final max = item.activeQuantity;
                    final lineRefund = item.unitPrice * order.discountFactor * qty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.menuItem.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '${_currency.format(item.unitPrice * order.discountFactor)} each'
                                  ' · ${item.activeQuantity} available',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          // Quantity stepper
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: qty > 0
                                      ? () => setSt(
                                          () => refundQtys[item.id] = qty - 1)
                                      : null,
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(7)),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.remove,
                                        size: 16,
                                        color: qty > 0
                                            ? Colors.black87
                                            : Colors.grey.shade300),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 32,
                                  alignment: Alignment.center,
                                  color: qty > 0
                                      ? _kAccentBg
                                      : Colors.transparent,
                                  child: Text(
                                    '$qty',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: qty > 0
                                            ? _kAccent
                                            : Colors.black38),
                                  ),
                                ),
                                InkWell(
                                  onTap: qty < max
                                      ? () => setSt(
                                          () => refundQtys[item.id] = qty + 1)
                                      : null,
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(7)),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.add,
                                        size: 16,
                                        color: qty < max
                                            ? Colors.black87
                                            : Colors.grey.shade300),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 68,
                            child: Text(
                              lineRefund > 0
                                  ? _currency.format(lineRefund)
                                  : '—',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: lineRefund > 0
                                      ? Colors.red.shade500
                                      : Colors.grey.shade400),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total refund:',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                      Text(
                        totalRefund > 0
                            ? _currency.format(totalRefund)
                            : '—',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: totalRefund > 0
                                ? Colors.red.shade500
                                : Colors.grey.shade400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inventory will be restored for refunded units.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed:
                    anySelected ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent, foregroundColor: Colors.white),
                child: const Text('Process Refund'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    int processedCount = 0;
    int failCount = 0;
    for (final item in refundable) {
      final qty = refundQtys[item.id] ?? 0;
      if (qty > 0) {
        try {
          await _service.refundOrderItem(order.id, item.id, qty);
          processedCount++;
        } catch (_) {
          failCount++;
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failCount > 0
            ? '$processedCount item line(s) refunded. $failCount failed — please retry.'
            : '$processedCount item line(s) refunded. (Inventory unchanged — food was served.)'),
        backgroundColor: failCount > 0 ? Colors.red : _kAccent,
      ),
    );
    _load();
  }

  void _showInvoice(RestaurantOrder order) {
    final table = order.tableId != null
        ? _tables.firstWhere((t) => t.id == order.tableId,
            orElse: () =>
                RestaurantTable(id: '', tableNumber: '?', capacity: 0))
        : null;
    showDialog(
      context: context,
      builder: (_) => RestaurantInvoiceDialog(order: order, table: table),
    );
  }

  // ─── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(),
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
                color: _kAccentBg, borderRadius: BorderRadius.circular(10)),
            child:
                const Icon(Icons.receipt_long_rounded, color: _kAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Text('Order Management',
              style: Theme.of(context).textTheme.displayMedium),
          const Spacer(),
          Text('${_filtered.length} orders',
              style: const TextStyle(
                  color: Colors.black38,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
                foregroundColor: _kAccent,
                side: const BorderSide(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final f in _DateFilter.values)
                      ChoiceChip(
                        label: Text(_dateLbl(f),
                            style: TextStyle(
                                color: _dateFilter == f ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        selected: _dateFilter == f,
                        onSelected: (_) => setState(() => _dateFilter = f),
                        selectedColor: _kAccent,
                        backgroundColor: Colors.grey.shade100,
                      ),
                    const SizedBox(width: 8),
                    const Text('Status:',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontWeight: FontWeight.w600)),
                    _statusChip(null, 'All', Colors.blueGrey),
                    for (final s in OrderStatus.values)
                      _statusChip(s, _statusLbl(s), _statusColor(s)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search order #...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(OrderStatus? s, String label, Color color) {
    final sel = _statusFilter == s;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: sel ? Colors.white : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
      selected: sel,
      onSelected: (_) => setState(() => _statusFilter = s),
      selectedColor: color,
      backgroundColor: Colors.grey.shade50,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildList() {
    final orders = _filtered;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No orders found',
                style: TextStyle(color: Colors.black38, fontSize: 15)),
          ],
        ),
      );
    }

    // Group child orders under their parent using parentOrderId.
    // Child orders are not shown as top-level rows.
    final childrenByParent = <String, List<RestaurantOrder>>{};
    final childIds = <String>{};

    for (final o in orders) {
      if (o.parentOrderId != null) {
        childrenByParent.putIfAbsent(o.parentOrderId!, () => []).add(o);
        childIds.add(o.id);
      }
    }

    final items = <Widget>[];
    for (final o in orders) {
      if (childIds.contains(o.id)) continue; // rendered under parent
      final children = childrenByParent[o.id] ?? [];
      if (children.isEmpty) {
        items.add(_buildOrderCard(o));
      } else {
        children.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        items.add(_buildSessionCard(o, children));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _buildSessionCard(RestaurantOrder parent, List<RestaurantOrder> children) {
    final allOrders = [parent, ...children];
    final tableName = _tableName(parent.tableId);
    final combinedSubtotal =
        allOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final totalItems = allOrders.fold(
        0,
        (s, o) =>
            s + o.items.fold(0, (s2, i) => s2 + (i.quantity - i.refundedQuantity)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kAccentBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${parent.orderNumber}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _kAccent),
                ),
              ),
              const SizedBox(width: 8),
              if (parent.tableId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tableName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.teal.shade700),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _chip('${children.length} ADD-ON${children.length == 1 ? "" : "S"}',
                  Colors.teal.shade700, icon: Icons.add_circle_outline_rounded),
              const SizedBox(width: 6),
              _chip(_paymentLbl(parent.paymentStatus),
                  _paymentColor(parent.paymentStatus),
                  icon: _paymentIcon(parent.paymentStatus)),
              const Spacer(),
              Text(
                DateFormat('MMM d, HH:mm').format(parent.createdAt),
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              '${allOrders.map((o) => "#${o.orderNumber}").join(" + ")}  ·  $totalItems item(s)  ·  Combined: ${_currency.format(combinedSubtotal)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          children: allOrders
              .map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: o.parentOrderId != null
                              ? Colors.teal.shade100
                              : Colors.grey.shade200,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildOrderCard(o, nested: true),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(RestaurantOrder order, {bool nested = false}) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final isServed = order.status == OrderStatus.served;
    final canCancel = !isCancelled && !isServed;
    final hasRefundable = isServed && order.items.any((i) => !i.isFullyRefunded);
    final totalRefunded = order.items.fold(
        0.0, (s, i) => s + i.unitPrice * order.discountFactor * i.refundedQuantity);

    return Container(
      margin: nested ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      decoration: nested
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:
                  isCancelled ? Border.all(color: Colors.red.shade100) : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─ Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red.shade50 : _kAccentBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${order.orderNumber}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isCancelled ? Colors.red.shade600 : _kAccent),
                  ),
                ),
                const SizedBox(width: 10),
                _chip(_statusLbl(order.status), _statusColor(order.status),
                    icon: _statusIcon(order.status)),
                const SizedBox(width: 6),
                _chip(_paymentLbl(order.paymentStatus),
                    _paymentColor(order.paymentStatus),
                    icon: _paymentIcon(order.paymentStatus)),
                const Spacer(),
                Text(
                  DateFormat('MMM d, HH:mm').format(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ─ Meta
            Row(
              children: [
                _metaIcon(Icons.table_restaurant_rounded, _tableName(order.tableId)),
                const SizedBox(width: 16),
                _metaIcon(
                    order.type == OrderType.dineIn
                        ? Icons.restaurant_rounded
                        : Icons.takeout_dining_rounded,
                    order.type == OrderType.dineIn ? 'Dine-in' : 'Takeaway'),
                const SizedBox(width: 16),
                _metaIcon(Icons.shopping_bag_outlined,
                    '${order.items.length} item${order.items.length == 1 ? '' : 's'}'),
              ],
            ),
            const SizedBox(height: 10),
            // ─ Items preview
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: order.items.map((item) {
                final fullyRefunded = item.isFullyRefunded;
                final partiallyRefunded =
                    !fullyRefunded && item.refundedQuantity > 0;
                String label = '${item.menuItem.name} ×${item.quantity}';
                if (fullyRefunded) {
                  label += ' (refunded)';
                } else if (partiallyRefunded) {
                  label += ' (${item.refundedQuantity} refunded)';
                }
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fullyRefunded
                        ? Colors.grey.shade100
                        : partiallyRefunded
                            ? Colors.orange.shade50
                            : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: partiallyRefunded
                            ? Colors.orange.shade200
                            : Colors.grey.shade200),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 11,
                        color: fullyRefunded
                            ? Colors.grey.shade400
                            : partiallyRefunded
                                ? Colors.orange.shade700
                                : Colors.black54,
                        decoration: fullyRefunded
                            ? TextDecoration.lineThrough
                            : null),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // ─ Footer
            Row(
              children: [
                if (totalRefunded > 0) ...[
                  Text(
                    'Refunded: ${_currency.format(totalRefunded)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                ],
                Text('Total: ',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade500)),
                Text(
                  _currency.format(order.totalAmount),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kAccent),
                ),
                const Spacer(),
                // Invoice
                OutlinedButton.icon(
                  onPressed: () => _showInvoice(order),
                  icon: const Icon(Icons.receipt_outlined, size: 14),
                  label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (hasRefundable && canEditSection(ref, 'restaurant_orders')) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showRefundDialog(order),
                    icon: const Icon(Icons.undo_rounded, size: 14),
                    label: const Text('Refund', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kAccent,
                      side: const BorderSide(color: _kAccent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
                if (canCancel && canEditSection(ref, 'restaurant_orders')) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _cancelOrder(order),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:    return Icons.schedule_rounded;
      case OrderStatus.preparing:  return Icons.local_fire_department_rounded;
      case OrderStatus.ready:      return Icons.check_circle_rounded;
      case OrderStatus.served:     return Icons.done_all_rounded;
      case OrderStatus.cancelled:  return Icons.cancel_rounded;
    }
  }

  IconData _paymentIcon(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:          return Icons.check_circle_rounded;
      case PaymentStatus.chargedToRoom: return Icons.hotel_rounded;
      case PaymentStatus.unpaid:        return Icons.error_outline_rounded;
    }
  }

  Widget _metaIcon(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.black38),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
      ],
    );
  }

  String _dateLbl(_DateFilter f) {
    switch (f) {
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.week:
        return 'This Week';
      case _DateFilter.all:
        return 'All Time';
    }
  }

  String _statusLbl(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Colors.amber.shade700;
      case OrderStatus.preparing:
        return const Color(0xFF3B82F6);
      case OrderStatus.ready:
        return const Color(0xFF22C55E);
      case OrderStatus.served:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _paymentLbl(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.chargedToRoom:
        return 'Room';
      case PaymentStatus.unpaid:
        return 'Unpaid';
    }
  }

  Color _paymentColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:
        return const Color(0xFF22C55E);
      case PaymentStatus.chargedToRoom:
        return Colors.amber.shade700;
      case PaymentStatus.unpaid:
        return Colors.red;
    }
  }
}
