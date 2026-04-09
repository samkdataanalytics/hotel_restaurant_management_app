import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant_table.dart';
import '../../providers/hotel_session.dart' show hexToColor;
import '../../services/guest_menu_service.dart';

// ─── Colour palette (navy + gold) ─────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF0F172A);
  static const surface   = Color(0xFF1E293B);
  static const card      = Color(0xFF263245);
  static const gold      = Color(0xFFD4A853);
  static const text      = Colors.white;
  static const subtext   = Color(0xFF94A3B8);
  static const divider   = Color(0xFF334155);
}

// ─── Cart entry ───────────────────────────────────────────────────────────────
class _CartItem {
  final MenuItem item;
  int qty;
  String notes;
  _CartItem({required this.item, this.qty = 1, this.notes = ''});
  double get subtotal => item.price * qty;
}

// ─── Placed order record ──────────────────────────────────────────────────────
class _PlacedOrder {
  final String id;
  final List<_CartItem> items;
  final bool isAddOn;       // true if parentOrderId was set
  String status;
  String paymentStatus;
  StreamSubscription<({String status, String paymentStatus})>? sub;

  _PlacedOrder({
    required this.id,
    required this.items,
    required this.isAddOn,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
  });

  bool get isActive =>
      status != 'served' && status != 'cancelled';

  bool get isPaid =>
      paymentStatus == 'paid' || paymentStatus == 'charged_to_room';

  double get subtotal => items.fold(0.0, (s, c) => s + c.subtotal);
}

// ─── Main screen ──────────────────────────────────────────────────────────────
class GuestMenuScreen extends StatefulWidget {
  final String propertyId;
  final String tableId;
  const GuestMenuScreen({
    super.key,
    required this.propertyId,
    required this.tableId,
  });

  @override
  State<GuestMenuScreen> createState() => _GuestMenuScreenState();
}

class _GuestMenuScreenState extends State<GuestMenuScreen>
    with SingleTickerProviderStateMixin {
  final _service = GuestMenuService();

  // ── Data ───────────────────────────────────────────────────────────────────
  RestaurantTable? _table;
  String _propertyName = '';
  Color _accent = _C.gold;
  String _logoUrl = '';
  List<MenuItem> _items = [];
  List<String> _categories = [];
  double _taxRate = 0;
  double _serviceRate = 0;
  bool _loading = true;
  String? _error;

  // ── Cart ───────────────────────────────────────────────────────────────────
  final List<_CartItem> _cart = [];

  // ── UI state ───────────────────────────────────────────────────────────────
  String? _selectedCategory;
  late TabController _tabController;

  // ── Multi-order state ─────────────────────────────────────────────────────
  // All orders placed in this session (index 0 = parent, rest = add-ons)
  final List<_PlacedOrder> _orders = [];
  bool _isPlacing = false;
  // When true, user is back on menu to add more items
  bool _addingMore = false;

  // ── Feedback + session state ───────────────────────────────────────────────
  bool _showFeedback = false;
  bool _sessionEnded = false;
  int _feedbackRating = 0;           // 0 = not selected
  final _feedbackController = TextEditingController();
  bool _isSubmittingFeedback = false;

  // ── Computed ───────────────────────────────────────────────────────────────
  bool get _hasOrders => _orders.isNotEmpty;

  // Allow "Add More" when at least one order is active (not served/cancelled)
  bool get _canAddMore =>
      _orders.any((o) => o.isActive) && !_addingMore;

  // Primary order (first one placed)
  _PlacedOrder? get _primaryOrder =>
      _orders.isNotEmpty ? _orders.first : null;

  double get _cartSubtotal => _cart.fold(0.0, (s, c) => s + c.subtotal);
  double get _allOrdersSubtotal =>
      _orders.fold(0.0, (s, o) => s + o.subtotal);
  double get _tax => _allOrdersSubtotal * (_taxRate / 100);
  double get _serviceCharge => _allOrdersSubtotal * (_serviceRate / 100);
  double get _grandTotal => _allOrdersSubtotal + _tax + _serviceCharge;

  int get _totalCartItems => _cart.fold(0, (s, c) => s + c.qty);

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    for (final o in _orders) { o.sub?.cancel(); }
    super.dispose();
  }

  // ── Load menu data ─────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.getAvailableMenuItems(widget.propertyId),
        _service.getTable(widget.propertyId, widget.tableId),
        _service.getPropertyName(widget.propertyId),
        _service.getSettings(widget.propertyId),
      ]);
      final items    = results[0] as List<MenuItem>;
      final table    = results[1] as RestaurantTable?;
      final name     = results[2] as String;
      final settings = results[3] as ({double taxRate, double serviceChargeRate, String primaryColorHex, String logoUrl});
      final cats = items.map((e) => e.category).toSet().toList()..sort();
      _tabController.dispose();
      _tabController = TabController(length: cats.length, vsync: this)
        ..addListener(() {
          if (!_tabController.indexIsChanging) {
            setState(() => _selectedCategory = cats[_tabController.index]);
          }
        });
      setState(() {
        _items         = items;
        _table         = table;
        _propertyName  = name;
        _taxRate       = settings.taxRate;
        _serviceRate   = settings.serviceChargeRate;
        _accent        = hexToColor(settings.primaryColorHex);
        _logoUrl       = settings.logoUrl;
        _categories    = cats;
        _selectedCategory = cats.isNotEmpty ? cats.first : null;
        _loading       = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Cart helpers ───────────────────────────────────────────────────────────
  void _addToCart(MenuItem item) {
    setState(() {
      final existing = _cart.where((c) => c.item.id == item.id).firstOrNull;
      if (existing != null) existing.qty++;
      else _cart.add(_CartItem(item: item));
    });
  }

  void _removeFromCart(MenuItem item) {
    setState(() {
      final existing = _cart.where((c) => c.item.id == item.id).firstOrNull;
      if (existing == null) return;
      if (existing.qty > 1) existing.qty--;
      else _cart.removeWhere((c) => c.item.id == item.id);
    });
  }

  int _qtyInCart(MenuItem item) =>
      _cart.where((c) => c.item.id == item.id).firstOrNull?.qty ?? 0;

  // ── Place / add-on order ───────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _isPlacing = true);

    // For add-on orders, link to the primary order
    final parentId = _addingMore ? _primaryOrder?.id : null;

    try {
      final id = await _service.placeOrder(
        propertyId: widget.propertyId,
        tableId:    widget.tableId,
        cartItems:  _cart.map((c) => (item: c.item, qty: c.qty, notes: c.notes)).toList(),
        parentOrderId: parentId,
      );

      final placed = _PlacedOrder(
        id: id,
        items: List.of(_cart),
        isAddOn: parentId != null,
      );

      // Watch this order's status + payment_status in real-time
      placed.sub = _service.watchOrder(id).listen((data) {
        if (!mounted) return;
        setState(() {
          placed.status = data.status;
          placed.paymentStatus = data.paymentStatus;
          // Trigger feedback form when payment is collected
          if (placed.isPaid && !_showFeedback && !_sessionEnded) {
            _showFeedback = true;
          }
        });
      });

      setState(() {
        _orders.add(placed);
        _cart.clear();
        _isPlacing   = false;
        _addingMore  = false;
      });
    } catch (e) {
      setState(() => _isPlacing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── "Add more items" — go back to menu ────────────────────────────────────
  void _startAddMore() {
    setState(() {
      _cart.clear();
      _addingMore = true;
    });
  }

  // ── Logo helper ────────────────────────────────────────────────────────────
  Widget _logoWidget(double size) {
    if (_logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          _logoUrl,
          width: size, height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/hotrest_logo.webp', width: size, height: size),
        ),
      );
    }
    return Image.asset('assets/images/hotrest_logo.webp', width: size, height: size);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_error != null) return _errorView();
    if (_sessionEnded) return _sessionEndedView();
    if (_showFeedback) return _feedbackView();

    // Show menu if no orders yet OR user is adding more
    if (!_hasOrders || _addingMore) return _menuView();

    // Otherwise show the order tracking / confirmation screen
    return _orderTrackingView();
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _loadingView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _logoWidget(80),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: _C.gold),
        const SizedBox(height: 16),
        const Text('Loading menu…', style: TextStyle(color: _C.subtext, fontSize: 14)),
      ]),
    ),
  );

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _errorView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          const Text('Could not load menu',
              style: TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: _C.subtext, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: _C.gold, foregroundColor: _C.bg),
          ),
        ]),
      ),
    ),
  );

  // ── Order tracking screen ─────────────────────────────────────────────────
  Widget _orderTrackingView() {
    final allServed = _orders.isNotEmpty && _orders.every((o) => o.status == 'served');
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 2);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                _logoWidget(36),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_propertyName,
                        style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    if (_table != null)
                      Text('Table ${_table!.tableNumber}',
                          style: const TextStyle(color: _C.subtext, fontSize: 12)),
                  ],
                )),
              ]),
              const SizedBox(height: 24),

              // Per-order status cards
              ..._orders.map((order) => _orderStatusCard(order, fmt)),

              const SizedBox(height: 20),

              // Combined invoice
              _combinedInvoice(fmt),

              const SizedBox(height: 20),

              // Action buttons
              if (_canAddMore)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _startAddMore,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add More Items',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.gold,
                      foregroundColor: _C.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

              if (allServed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      for (final o in _orders) o.sub?.cancel();
                      _orders.clear();
                    }),
                    icon: const Icon(Icons.replay_rounded, color: _C.gold),
                    label: const Text('Start New Order',
                        style: TextStyle(color: _C.gold, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              const Center(
                child: Text('Payment will be collected by your server.',
                    style: TextStyle(color: _C.subtext, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderStatusCard(_PlacedOrder order, NumberFormat fmt) {
    final info = _statusInfo(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Status header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(info.icon, key: ValueKey(order.status),
                    color: info.color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(order.isAddOn ? 'Add-on Order' : 'Order',
                        style: const TextStyle(color: _C.subtext, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: info.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(info.label,
                          style: TextStyle(color: info.color,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(info.description,
                      style: const TextStyle(color: _C.subtext, fontSize: 11)),
                ],
              )),
              Text(fmt.format(order.subtotal),
                  style: const TextStyle(color: _C.gold,
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: order.items.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _C.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${c.qty}',
                        style: const TextStyle(color: _C.gold,
                            fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.item.name,
                      style: const TextStyle(color: _C.text, fontSize: 13))),
                  Text(fmt.format(c.subtotal),
                      style: const TextStyle(color: _C.subtext, fontSize: 12)),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _combinedInvoice(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Invoice Summary',
            style: TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 12),
        // All items across all orders
        ..._orders.expand((o) => o.items).map((c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Text('${c.qty}×', style: const TextStyle(color: _C.subtext, fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(child: Text(c.item.name,
                style: const TextStyle(color: _C.subtext, fontSize: 12))),
            Text(fmt.format(c.subtotal),
                style: const TextStyle(color: _C.subtext, fontSize: 12)),
          ]),
        )),
        const Divider(color: _C.divider, height: 20),
        _invoiceRow('Subtotal', _allOrdersSubtotal, fmt),
        if (_taxRate > 0)
          _invoiceRow('Tax (${_taxRate.toStringAsFixed(0)}%)', _tax, fmt),
        if (_serviceRate > 0)
          _invoiceRow('Service (${_serviceRate.toStringAsFixed(0)}%)', _serviceCharge, fmt),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(fmt.format(_grandTotal),
                style: const TextStyle(color: _C.gold,
                    fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        if (_orders.length > 1) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline_rounded, color: _C.subtext, size: 13),
            const SizedBox(width: 4),
            Text('Includes ${_orders.length} orders',
                style: const TextStyle(color: _C.subtext, fontSize: 11)),
          ]),
        ],
      ]),
    );
  }

  Widget _invoiceRow(String label, double value, NumberFormat fmt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
        Text(fmt.format(value), style: const TextStyle(color: _C.subtext, fontSize: 13)),
      ],
    ),
  );

  // ── Feedback screen ────────────────────────────────────────────────────────
  Widget _feedbackView() {
    const emojis = ['😞', '😕', '😐', '😊', '😍'];
    const labels = ['Very Bad', 'Bad', 'Okay', 'Good', 'Excellent'];

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _logoWidget(72),
              const SizedBox(height: 24),
              const Text('Payment received!',
                  style: TextStyle(color: _C.gold, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('How was your experience?',
                  style: TextStyle(color: _C.text, fontSize: 22,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('${_table != null ? "Table ${_table!.tableNumber} · " : ""}$_propertyName',
                  style: const TextStyle(color: _C.subtext, fontSize: 13)),
              const SizedBox(height: 32),

              // Emoji rating row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final selected = _feedbackRating == i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _feedbackRating = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: selected ? 64 : 52,
                      height: selected ? 64 : 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? _C.gold.withOpacity(0.2)
                            : _C.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? _C.gold : _C.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(emojis[i],
                            style: TextStyle(fontSize: selected ? 30 : 24)),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              if (_feedbackRating > 0)
                Text(labels[_feedbackRating - 1],
                    style: const TextStyle(color: _C.gold,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 28),

              // Comment field
              Container(
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.divider),
                ),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 3,
                  style: const TextStyle(color: _C.text, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Share your experience (optional)…',
                    hintStyle: TextStyle(color: _C.subtext, fontSize: 14),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_feedbackRating == 0 || _isSubmittingFeedback)
                      ? null
                      : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.gold,
                    foregroundColor: _C.bg,
                    disabledBackgroundColor: _C.gold.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmittingFeedback
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: _C.bg, strokeWidth: 2))
                      : const Text('Submit Feedback',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),

              // Skip button
              TextButton(
                onPressed: _skipFeedback,
                child: const Text('Skip',
                    style: TextStyle(color: _C.subtext, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitFeedback() async {
    if (_feedbackRating == 0) return;
    setState(() => _isSubmittingFeedback = true);
    try {
      await _service.submitFeedback(
        propertyId: widget.propertyId,
        tableId:    widget.tableId,
        orderId:    _primaryOrder?.id ?? '',
        rating:     _feedbackRating,
        comment:    _feedbackController.text.trim(),
      );
    } catch (_) {
      // Silently ignore — don't block guest from ending session
    }
    if (mounted) setState(() { _sessionEnded = true; _showFeedback = false; });
  }

  void _skipFeedback() {
    setState(() { _sessionEnded = true; _showFeedback = false; });
  }

  // ── Session ended screen ───────────────────────────────────────────────────
  Widget _sessionEndedView() => Scaffold(
    backgroundColor: _C.bg,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _logoWidget(80),
              const SizedBox(height: 32),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: _C.gold, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Thank You!',
                  style: TextStyle(color: _C.text, fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('We hope you enjoyed your visit at $_propertyName.',
                  style: const TextStyle(color: _C.subtext, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.divider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_rounded, color: _C.subtext, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This session has ended.\nScan the QR code again for a new order.',
                        style: TextStyle(color: _C.subtext, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Menu view ──────────────────────────────────────────────────────────────
  Widget _menuView() {
    final visibleItems = _selectedCategory == null
        ? _items
        : _items.where((i) => i.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _buildHeader(),
        if (_categories.isNotEmpty) _buildCategoryTabs(),
        Expanded(
          child: visibleItems.isEmpty
              ? const Center(child: Text('No items available',
                  style: TextStyle(color: _C.subtext)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: visibleItems.length,
                  itemBuilder: (_, i) => _itemCard(visibleItems[i]),
                ),
        ),
      ]),
      floatingActionButton: _totalCartItems > 0 ? _cartFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.divider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            _logoWidget(36),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_propertyName,
                    style: const TextStyle(color: _C.text,
                        fontWeight: FontWeight.w700, fontSize: 16),
                    overflow: TextOverflow.ellipsis),
                if (_table != null)
                  Text('Table ${_table!.tableNumber} · ${_table!.capacity} seats',
                      style: const TextStyle(color: _C.subtext, fontSize: 12)),
              ],
            )),
            // "Back to order" button when adding more
            if (_addingMore)
              TextButton.icon(
                onPressed: () => setState(() {
                  _cart.clear();
                  _addingMore = false;
                }),
                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: _C.gold),
                label: const Text('My Order', style: TextStyle(color: _C.gold, fontSize: 13)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.gold.withOpacity(0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.restaurant_menu_rounded, color: _C.gold, size: 14),
                  SizedBox(width: 4),
                  Text('Menu', style: TextStyle(color: _C.gold,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: _C.surface,
      height: 46,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: _C.gold.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        dividerColor: _C.divider,
        labelColor: _C.gold,
        unselectedLabelColor: _C.subtext,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: _categories.map((c) => Tab(text: c)).toList(),
      ),
    );
  }

  Widget _itemCard(MenuItem item) {
    final qty = _qtyInCart(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: qty > 0
            ? Border.all(color: _C.gold.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: item.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(item.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.fastfood_rounded, color: _C.subtext, size: 28)),
                )
              : const Icon(Icons.fastfood_rounded, color: _C.subtext, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name,
                style: const TextStyle(color: _C.text,
                    fontWeight: FontWeight.w700, fontSize: 14)),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(item.description,
                  style: const TextStyle(color: _C.subtext, fontSize: 11),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Text(NumberFormat.currency(symbol: '', decimalDigits: 2).format(item.price),
                style: const TextStyle(color: _C.gold,
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        )),
        const SizedBox(width: 8),
        qty == 0
            ? GestureDetector(
                onTap: () => _addToCart(item),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: _C.gold, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: _C.bg, size: 20),
                ),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => _removeFromCart(item),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _C.surface, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _C.divider),
                    ),
                    child: const Icon(Icons.remove_rounded, color: _C.text, size: 16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$qty',
                      style: const TextStyle(color: _C.gold,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                GestureDetector(
                  onTap: () => _addToCart(item),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: _C.gold, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_rounded, color: _C.bg, size: 16),
                  ),
                ),
              ]),
      ]),
    );
  }

  Widget _cartFab() {
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 2);
    // For add-on, show running total including previous orders
    final displayTotal = _addingMore
        ? _grandTotal + _cartSubtotal * (1 + _taxRate / 100 + _serviceRate / 100)
        : _cartSubtotal;

    return GestureDetector(
      onTap: _showCart,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _C.gold,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: _C.gold.withOpacity(0.4), blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: _C.bg.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('$_totalCartItems',
                style: const TextStyle(color: _C.bg,
                    fontWeight: FontWeight.w800, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _addingMore ? 'View Add-on Order' : 'View Order',
            style: const TextStyle(color: _C.bg, fontWeight: FontWeight.w700, fontSize: 15),
          )),
          Text(fmt.format(displayTotal),
              style: const TextStyle(color: _C.bg,
                  fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        cart: _cart,
        subtotal: _cartSubtotal,
        tax: _cartSubtotal * (_taxRate / 100),
        serviceCharge: _cartSubtotal * (_serviceRate / 100),
        total: _cartSubtotal * (1 + _taxRate / 100 + _serviceRate / 100),
        taxRate: _taxRate,
        serviceRate: _serviceRate,
        isPlacing: _isPlacing,
        isAddOn: _addingMore,
        onAdd: (item) { _addToCart(item); },
        onRemove: (item) { _removeFromCart(item); },
        onPlace: () { Navigator.pop(context); _placeOrder(); },
      ),
    );
  }

  // ── Status helper ──────────────────────────────────────────────────────────
  ({IconData icon, Color color, String label, String description}) _statusInfo(
      String status) {
    return switch (status) {
      'pending'   => (
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFF59E0B),
          label: 'Received',
          description: 'Your order has been received.',
        ),
      'preparing' => (
          icon: Icons.outdoor_grill_rounded,
          color: const Color(0xFF3B82F6),
          label: 'Preparing',
          description: 'The kitchen is preparing your order.',
        ),
      'ready'     => (
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
          label: 'Ready!',
          description: 'Your order is ready to be served.',
        ),
      'served'    => (
          icon: Icons.sentiment_very_satisfied_rounded,
          color: _C.gold,
          label: 'Served',
          description: 'Enjoy your meal!',
        ),
      'cancelled' => (
          icon: Icons.cancel_rounded,
          color: Colors.redAccent,
          label: 'Cancelled',
          description: 'This order was cancelled.',
        ),
      _ => (
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFF59E0B),
          label: 'Received',
          description: 'Your order has been received.',
        ),
    };
  }
}

// ─── Cart bottom sheet ────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final List<_CartItem> cart;
  final double subtotal, tax, serviceCharge, total, taxRate, serviceRate;
  final bool isPlacing;
  final bool isAddOn;
  final void Function(MenuItem) onAdd;
  final void Function(MenuItem) onRemove;
  final VoidCallback onPlace;

  const _CartSheet({
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.serviceCharge,
    required this.total,
    required this.taxRate,
    required this.serviceRate,
    required this.isPlacing,
    required this.isAddOn,
    required this.onAdd,
    required this.onRemove,
    required this.onPlace,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final fmt = NumberFormat.currency(symbol: '', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: _C.divider, borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Text(
                widget.isAddOn ? 'Add-on Items' : 'Your Order',
                style: const TextStyle(color: _C.text,
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (widget.isAddOn) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Add-on',
                      style: TextStyle(color: _C.gold, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              Text('${widget.cart.fold(0, (s, c) => s + c.qty)} items',
                  style: const TextStyle(color: _C.subtext, fontSize: 13)),
            ]),
          ),
          const Divider(color: _C.divider, height: 1),
          // Items list
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.cart.length,
              itemBuilder: (_, i) {
                final c = widget.cart[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: () { widget.onRemove(c.item); setState(() {}); },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _C.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _C.divider),
                          ),
                          child: const Icon(Icons.remove_rounded, color: _C.text, size: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${c.qty}',
                            style: const TextStyle(color: _C.gold,
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      GestureDetector(
                        onTap: () { widget.onAdd(c.item); setState(() {}); },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              color: _C.gold, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add_rounded, color: _C.bg, size: 14),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.item.name,
                        style: const TextStyle(color: _C.text, fontSize: 14,
                            fontWeight: FontWeight.w500))),
                    Text(fmt.format(c.subtotal),
                        style: const TextStyle(color: _C.subtext, fontSize: 13)),
                  ]),
                );
              },
            ),
          ),
          const Divider(color: _C.divider, height: 1),
          // Totals + button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(children: [
              _totalRow('Subtotal', widget.subtotal),
              if (widget.taxRate > 0)
                _totalRow('Tax (${widget.taxRate.toStringAsFixed(0)}%)', widget.tax),
              if (widget.serviceRate > 0)
                _totalRow('Service (${widget.serviceRate.toStringAsFixed(0)}%)',
                    widget.serviceCharge),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.isAddOn ? 'This order' : 'Total',
                      style: const TextStyle(color: _C.text,
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(fmt.format(widget.total),
                      style: const TextStyle(color: _C.gold,
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              if (widget.isAddOn) ...[
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline_rounded, color: _C.subtext, size: 13),
                    SizedBox(width: 4),
                    Text('Will be added to your table bill',
                        style: TextStyle(color: _C.subtext, fontSize: 11)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.isPlacing ? null : widget.onPlace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.gold,
                    foregroundColor: _C.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: widget.isPlacing
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: _C.bg, strokeWidth: 2))
                      : Text(
                          widget.isAddOn ? 'Add to Order' : 'Place Order',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _totalRow(String label, double value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
        Text(fmt.format(value), style: const TextStyle(color: _C.subtext, fontSize: 13)),
      ],
    ),
  );
}
