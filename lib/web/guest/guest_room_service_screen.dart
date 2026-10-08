import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/menu_item.dart';
import '../../providers/hotel_session.dart' show hexToColor;
import '../../services/guest_menu_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/service_providers.dart';

// ─── Colour palette (same as guest menu portal) ───────────────────────────────
class _C {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const card    = Color(0xFF263245);
  static const gold    = Color(0xFF3FBDB4);
  static const text    = Colors.white;
  static const subtext = Color(0xFF94A3B8);
  static const divider = Color(0xFF334155);
  static const purple  = Color(0xFF8B5CF6); // room service accent
}

class _CartItem {
  final MenuItem item;
  int qty;
  String notes = '';
  final Map<String, List<String>> selectedModifiers;

  _CartItem({
    required this.item,
    this.qty = 1,
    Map<String, List<String>>? modifiers,
  }) : selectedModifiers = modifiers ?? {};

  /// Matches OrderItem.unitPrice logic from POS exactly.
  double get unitPrice {
    int extraUnits = 0;
    double adjustmentsTotal = 0.0;
    for (final mod in item.modifiers) {
      final selected = selectedModifiers[mod.name] ?? [];
      if (selected.length > 1) extraUnits += selected.length - 1;
      for (final optName in selected) {
        final opt = mod.options.where((o) => o.name == optName).firstOrNull;
        if (opt != null) adjustmentsTotal += opt.priceAdjustment;
      }
    }
    return item.price * (1 + extraUnits) + adjustmentsTotal;
  }

  double get subtotal => unitPrice * qty;
}

// ─── Placed order ─────────────────────────────────────────────────────────────
class _PlacedOrder {
  final String id;
  final List<_CartItem> items;
  final bool isAddOn;
  String status = 'pending';
  String paymentStatus = 'unpaid';

  _PlacedOrder({
    required this.id,
    required this.items,
    this.isAddOn = false,
  });

  bool get isActive => status != 'served' && status != 'cancelled';
  bool get isPaid =>
      paymentStatus == 'paid' || paymentStatus == 'chargedToRoom';
  double get subtotal => items.fold(0.0, (s, c) => s + c.subtotal);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class GuestRoomServiceScreen extends ConsumerStatefulWidget {
  final String propertyId;
  final String roomNumber;

  const GuestRoomServiceScreen({
    super.key,
    required this.propertyId,
    required this.roomNumber,
  });

  @override
  ConsumerState<GuestRoomServiceScreen> createState() => _GuestRoomServiceScreenState();
}

class _GuestRoomServiceScreenState extends ConsumerState<GuestRoomServiceScreen>
    with TickerProviderStateMixin {
  GuestMenuService get _service => ref.read(guestMenuServiceProvider);
  NumberFormat get _fmt => NumberFormat.currency(symbol: _currencySymbol, decimalDigits: 2);
  late TabController _tabCtrl;

  // Brand color + logo (loaded from DB)
  Color _accent = _C.gold;
  String _logoUrl = '';

  // Data
  bool _loading = true;
  String? _error;
  String _propertyName = '';
  List<MenuItem> _menu = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  double _taxRate = 0.0;
  double _serviceRate = 0.0;
  String _currencySymbol = '\$';

  // Cart
  final List<_CartItem> _cart = [];

  // Orders
  final List<_PlacedOrder> _orders = [];
  bool _addingMore = false;
  bool _isPlacing = false;

  // Polling timer for order status
  Timer? _pollTimer;

  // Cancellation
  String? _cancellingOrderId;

  // Feedback / session
  bool _showFeedback = false;
  bool _sessionEnded = false;
  int _feedbackRating = 0;
  bool _isSubmittingFeedback = false;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 0, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabCtrl.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  /// Starts polling all active orders every 5 s via plain REST (no WebSocket).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      bool changed = false;
      for (final order in _orders) {
        try {
          final result = await _service.fetchOrderStatus(order.id);
          if (result == null) continue;
          if (result.status != order.status ||
              result.paymentStatus != order.paymentStatus) {
            order.status = result.status;
            order.paymentStatus = result.paymentStatus;
            changed = true;
          }
        } catch (_) {}
      }
      if (changed && mounted) {
        setState(() {
          if (_orders.any((o) => o.isPaid) && !_showFeedback && !_sessionEnded) {
            _showFeedback = true;
          }
        });
      }
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.getAvailableMenuItems(widget.propertyId),
        _service.getSettings(widget.propertyId),
        _service.getPropertyName(widget.propertyId),
      ]);

      final items    = results[0] as List<MenuItem>;
      final settings = results[1] as ({double taxRate, double serviceChargeRate, String primaryColorHex, String logoUrl, String currencySymbol});
      final name     = results[2] as String;

      final cats = items.map((i) => i.category).toSet().toList()..sort();

      if (!mounted) return;
      setState(() {
        _menu = items;
        _categories = cats;
        _selectedCategory = cats.isNotEmpty ? cats.first : '';
        _taxRate        = settings.taxRate;
        _serviceRate    = settings.serviceChargeRate;
        _accent         = hexToColor(settings.primaryColorHex);
        _logoUrl        = settings.logoUrl;
        _currencySymbol = settings.currencySymbol;
        _propertyName = name;
        _loading = false;
        _tabCtrl.dispose();
        _tabCtrl = TabController(length: cats.length, vsync: this);
        _tabCtrl.addListener(() {
          if (!_tabCtrl.indexIsChanging) {
            setState(() => _selectedCategory = cats[_tabCtrl.index]);
          }
        });
      });
    } catch (e) {
      debugPrint('❌ _load error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load menu: $e';
        _loading = false;
      });
    }
  }

  // ── Cart helpers ─────────────────────────────────────────────────────────────

  void _addItem(MenuItem item) {
    if (item.modifiers.isNotEmpty) {
      _showModifierDialog(item);
    } else {
      _addToCartWithMods(item, {}, 1);
    }
  }

  Future<void> _showModifierDialog(MenuItem item) async {
    final Map<String, List<String>> selections = {};
    for (final mod in item.modifiers) selections[mod.name] = [];
    int qty = 1;

    final result = await showDialog<({Map<String, List<String>> mods, int qty})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          bool isValid = true;
          for (final mod in item.modifiers) {
            if (mod.isRequired && selections[mod.name]!.isEmpty) {
              isValid = false; break;
            }
          }

          return AlertDialog(
            backgroundColor: _C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _C.divider)),
            title: Text('Customize ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: _C.text)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...item.modifiers.map((mod) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(mod.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _C.text)),
                                if (mod.isRequired)
                                  const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(mod.allowMultiple ? '(Qty per option)' : '(Choose 1)',
                                    style: const TextStyle(fontSize: 12, color: _C.subtext)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...mod.options.map((opt) {
                              final optionPrice = item.price + opt.priceAdjustment;
                              final priceLabel = opt.priceAdjustment == 0
                                  ? _fmt.format(item.price)   // base option — show actual price
                                  : '${_fmt.format(optionPrice)} (+${_fmt.format(opt.priceAdjustment)})';
                              if (mod.allowMultiple) {
                                final optQty = selections[mod.name]!.where((n) => n == opt.name).length;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(opt.name, style: const TextStyle(fontSize: 14, color: _C.text))),
                                      Text(priceLabel, style: const TextStyle(fontSize: 13, color: _C.subtext)),
                                      const SizedBox(width: 12),
                                      _qtyBtn(Icons.remove_rounded, () { if (optQty > 0) setSt(() => selections[mod.name]!.remove(opt.name)); }),
                                      SizedBox(
                                        width: 36,
                                        child: Text('$optQty', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: optQty > 0 ? _accent : _C.subtext)),
                                      ),
                                      _qtyBtn(Icons.add_rounded, () => setSt(() => selections[mod.name]!.add(opt.name))),
                                    ],
                                  ),
                                );
                              } else {
                                final isSelected = selections[mod.name]!.contains(opt.name);
                                return InkWell(
                                  onTap: () => setSt(() => selections[mod.name] = [opt.name]),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                          color: isSelected ? _accent : _C.subtext,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(opt.name, style: const TextStyle(fontSize: 14, color: _C.text))),
                                        Text(priceLabel, style: const TextStyle(fontSize: 13, color: _C.subtext)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            }),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: _C.divider),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Quantity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _C.text)),
                        const Spacer(),
                        _qtyBtn(Icons.remove_rounded, () { if (qty > 1) setSt(() => qty--); }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _C.text)),
                        ),
                        _qtyBtn(Icons.add_rounded, () => setSt(() => qty++)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _C.subtext))),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, (mods: selections, qty: qty)) : null,
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: _C.bg),
                child: Text('Add $qty to Order'),
              )
            ],
          );
        }
      )
    );

    if (result != null) {
      _addToCartWithMods(item, result.mods, result.qty);
    }
  }

  void _addToCartWithMods(MenuItem item, Map<String, List<String>> mods, int qty) {
    setState(() {
      final existing = _cart.where((c) {
        if (c.item.id != item.id) return false;
        if (c.selectedModifiers.length != mods.length) return false;
        for (final k in mods.keys) {
          if (!c.selectedModifiers.containsKey(k)) return false;
          final listA = List<String>.from(c.selectedModifiers[k]!)..sort();
          final listB = List<String>.from(mods[k]!)..sort();
          if (listA.join() != listB.join()) return false;
        }
        return true;
      }).firstOrNull;

      if (existing != null) {
        existing.qty += qty;
      } else {
        _cart.add(_CartItem(item: item, qty: qty, modifiers: mods));
      }
    });
  }

  void _removeItem(MenuItem item) {
    setState(() {
      final existing = _cart.where((c) => c.item.id == item.id).firstOrNull;
      if (existing == null) return;
      if (existing.qty > 1) {
        existing.qty--;
      } else {
        _cart.remove(existing);
      }
    });
  }

  int _qtyInCart(MenuItem item) =>
      _cart.where((c) => c.item.id == item.id).fold(0, (s, c) => s + c.qty);

  double get _cartSubtotal => _cart.fold(0.0, (s, c) => s + c.subtotal);
  double get _cartTax => _cartSubtotal * _taxRate;
  double get _cartService => _cartSubtotal * _serviceRate;
  double get _cartTotal => _cartSubtotal + _cartTax + _cartService;

  // ── Order more (with ready-state warning) ────────────────────────────────────

  Future<void> _onOrderMore() async {
    if (_orders.any((o) => o.status == 'ready')) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _C.divider),
          ),
          title: const Row(children: [
            Icon(Icons.delivery_dining_rounded, color: _C.purple, size: 20),
            SizedBox(width: 8),
            Text('Order already on its way',
                style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: const Text(
            'Your current order is already being delivered to your room.\n\n'
            'Adding more items will create a separate order that will be prepared and delivered after.',
            style: TextStyle(color: _C.subtext, fontSize: 14, height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel', style: TextStyle(color: _C.subtext)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.purple,
                foregroundColor: _C.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) setState(() => _addingMore = true);
    } else {
      setState(() => _addingMore = true);
    }
  }

  // ── Cancel order ─────────────────────────────────────────────────────────────

  Future<void> _cancelOrder(_PlacedOrder order) async {
    // Re-fetch live status before showing dialog — avoids stale UI state.
    final live = await _service.fetchOrderStatus(order.id);
    if (!mounted) return;

    if (live != null && live.status != 'pending') {
      // Already past pending — cannot cancel
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _C.divider),
          ),
          title: const Row(children: [
            Icon(Icons.restaurant_rounded, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text('Order already being prepared',
                style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: const Text(
            'The kitchen has already started preparing your order. '
            'Please speak to a staff member if you need to cancel.',
            style: TextStyle(color: _C.subtext, fontSize: 14, height: 1.55),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(_),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _C.purple, foregroundColor: _C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _C.divider),
        ),
        title: const Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
          SizedBox(width: 8),
          Text('Cancel this order?',
              style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Your order will be cancelled and removed from the kitchen queue.',
          style: TextStyle(color: _C.subtext, fontSize: 14, height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: const Text('Keep Order', style: TextStyle(color: _C.subtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancellingOrderId = order.id);
    try {
      final result = await _service.cancelOrder(order.id);
      if (!mounted) return;
      if (result == 'cancelled') {
        setState(() {
          order.status = 'cancelled';
          order.paymentStatus = 'unpaid';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (result == 'not_cancellable') {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _C.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _C.divider)),
            title: const Row(children: [
              Icon(Icons.restaurant_rounded, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('Too late to cancel',
                  style: TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            content: const Text(
              'The kitchen started preparing your order just now. '
              'Please speak to a staff member.',
              style: TextStyle(color: _C.subtext, fontSize: 14, height: 1.55),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(_),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _C.purple, foregroundColor: _C.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingOrderId = null);
    }
  }

  // ── Place order ──────────────────────────────────────────────────────────────

  Future<void> _placeOrder() async {
    if (_cart.isEmpty || _isPlacing) return;
    setState(() => _isPlacing = true);

    try {
      final parentId =
          _addingMore && _orders.isNotEmpty ? _orders.first.id : null;
      final id = await _service.placeOrder(
        propertyId: widget.propertyId,
        tableId: widget.roomNumber, // room number stored in tableId field
        cartItems: _cart.map((c) => (
          item: c.item, 
          qty: c.qty, 
          notes: c.notes,
          modifiers: c.selectedModifiers.isNotEmpty ? c.selectedModifiers : null
        )).toList(),
        parentOrderId: parentId,
        type: 'roomService',
      );

      final placed = _PlacedOrder(
        id: id,
        items: List.from(_cart),
        isAddOn: parentId != null,
      );

      setState(() {
        _orders.add(placed);
        _cart.clear();
        _addingMore = false;
      });

      // Start (or restart) the polling timer now that we have an active order.
      _startPolling();

    } catch (e) {
      debugPrint('❌ placeOrder error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_feedbackRating == 0 || _isSubmittingFeedback) return;
    setState(() => _isSubmittingFeedback = true);
    try {
      await _service.submitFeedback(
        propertyId: widget.propertyId,
        tableId: widget.roomNumber,
        orderId: _orders.first.id,
        rating: _feedbackRating,
        comment: _feedbackController.text.trim().isEmpty
            ? null
            : _feedbackController.text.trim(),
      );
    } catch (_) {}
    if (mounted) setState(() { _showFeedback = false; _sessionEnded = true; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_sessionEnded) return _sessionEndedView();
    if (_showFeedback) return _feedbackView();
    if (_error != null) return _errorView();
    if (_orders.isNotEmpty && !_addingMore) return _trackingView();
    return _menuView();
  }

  // ── Logo helper ──────────────────────────────────────────────────────────────
  Widget _logoWidget(double size) {
    if (_logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          _logoUrl,
          width: size, height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/hotrest_mark_light.png', width: size, height: size),
        ),
      );
    }
    return Image.asset('assets/images/hotrest_mark_light.png', width: size, height: size);
  }

  // ── Loading ───────────────────────────────────────────────────────────────────

  Widget _loadingView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _logoWidget(80),
      const SizedBox(height: 24),
      CircularProgressIndicator(color: _accent),
      const SizedBox(height: 16),
      const Text('Loading menu…', style: TextStyle(color: _C.subtext, fontSize: 14)),
    ])),
  );

  // ── Error ─────────────────────────────────────────────────────────────────────

  Widget _errorView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: _accent, size: 48),
        const SizedBox(height: 16),
        Text(_error!, style: const TextStyle(color: _C.subtext, fontSize: 14),
            textAlign: TextAlign.center),
      ]),
    )),
  );

  // ── Menu view ─────────────────────────────────────────────────────────────────

  Widget _menuView() => Scaffold(
    backgroundColor: _C.bg,
    appBar: AppBar(
      backgroundColor: _C.surface,
      elevation: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_propertyName,
            style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
        Row(children: [
          const Icon(Icons.hotel_rounded, color: _C.subtext, size: 14),
          const SizedBox(width: 4),
          Text('Room ${widget.roomNumber}',
              style: const TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _C.purple.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.purple.withAlpha(80)),
            ),
            child: const Text('Room Service',
                style: TextStyle(color: _C.purple, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
      actions: [
        if (_addingMore)
          TextButton.icon(
            onPressed: () => setState(() { _addingMore = false; _cart.clear(); }),
            icon: Icon(Icons.arrow_back_rounded, color: _accent, size: 16),
            label: Text('My Order', style: TextStyle(color: _accent, fontSize: 13)),
          ),
      ],
      bottom: _categories.length > 1
          ? TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              labelColor: _accent,
              unselectedLabelColor: _C.subtext,
              indicatorColor: _accent,
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            )
          : null,
    ),
    body: _buildMenuBody(),
    floatingActionButton: _cart.isEmpty ? null : FloatingActionButton.extended(
      backgroundColor: _accent,
      foregroundColor: _C.bg,
      onPressed: () => _showCartSheet(),
      icon: const Icon(Icons.shopping_cart_rounded),
      label: Text(
        '${_cart.fold(0, (s, c) => s + c.qty)} item${_cart.fold(0, (s, c) => s + c.qty) == 1 ? '' : 's'}'
        '  ·  ${_fmt.format(_cartTotal)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _buildMenuBody() {
    final items = _selectedCategory.isEmpty
        ? _menu
        : _menu.where((i) => i.category == _selectedCategory).toList();

    if (items.isEmpty) {
      return const Center(child: Text('No items available', style: TextStyle(color: _C.subtext)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _menuItemCard(items[i]),
    );
  }

  Widget _menuItemCard(MenuItem item) {
    final qty = _qtyInCart(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qty > 0 ? _accent.withAlpha(100) : _C.divider,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name,
              style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 15)),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.description,
                style: const TextStyle(color: _C.subtext, fontSize: 12), maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(_fmt.format(item.price),
              style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 14)),
          if (item.modifiers.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1, thickness: 0.8, color: _C.divider),
            ),
            ...item.modifiers.take(2).map((mod) {
              final optLabels = mod.options.map((o) => o.priceAdjustment != 0
                  ? '${o.name} (+${_fmt.format(o.priceAdjustment)})'
                  : o.name).join('  ·  ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mod.name,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.subtext)),
                    const SizedBox(height: 2),
                    Text(optLabels,
                        style: const TextStyle(fontSize: 10, color: _C.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            }),
            if (item.modifiers.length > 2)
              Text('+${item.modifiers.length - 2} more groups',
                  style: const TextStyle(fontSize: 10, color: _C.subtext)),
          ],
        ])),
        const SizedBox(width: 12),
        qty == 0
            ? GestureDetector(
                onTap: () => _addItem(item),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _accent, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: _C.bg, size: 20),
                ),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                _qtyBtn(Icons.remove_rounded, () => _removeItem(item)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$qty',
                      style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                _qtyBtn(Icons.add_rounded, () => _addItem(item)),
              ]),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: _C.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.divider),
      ),
      child: Icon(icon, color: _C.text, size: 14),
    ),
  );

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        cart: List.from(_cart),
        subtotal: _cartSubtotal,
        tax: _cartTax,
        taxRate: _taxRate,
        serviceCharge: _cartService,
        serviceRate: _serviceRate,
        total: _cartTotal,
        isAddOn: _addingMore,
        isPlacing: _isPlacing,
        onAdd: (c) => setState(() => c.qty++),
        onRemove: (c) => setState(() {
          if (c.qty > 1) {
            c.qty--;
          } else {
            _cart.remove(c);
            if (_cart.isEmpty) Navigator.pop(context);
          }
        }),
        onPlace: () { Navigator.pop(context); _placeOrder(); },
        currencySymbol: _currencySymbol,
        accent: _accent,
      ),
    );
  }

  // ── Order tracking ────────────────────────────────────────────────────────────

  Widget _trackingView() {
    final fmt = NumberFormat.currency(symbol: _currencySymbol, decimalDigits: 2);
    final activeOrders = _orders.where((o) => o.isActive).toList();
    final anyActive = activeOrders.isNotEmpty;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        title: Row(children: [
          const Icon(Icons.hotel_rounded, color: _C.subtext, size: 16),
          const SizedBox(width: 6),
          Text('Room ${widget.roomNumber}',
              style: const TextStyle(color: _C.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status cards
          ..._orders.map((o) => _orderStatusCard(o, fmt)),
          const SizedBox(height: 16),

          // Bill summary — always shown (single or multiple orders)
          _combinedInvoice(fmt),
          const SizedBox(height: 24),

          // Add more button
          if (anyActive) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _onOrderMore(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.add_shopping_cart_rounded, color: _accent),
                label: Text('Order More Items', style: TextStyle(color: _accent)),
              ),
            ),
            if (_orders.any((o) => o.status == 'ready')) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.delivery_dining_rounded, color: _C.purple, size: 14),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Your order is already on its way. New items will be a separate delivery.',
                      style: TextStyle(color: _C.purple, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _orderStatusCard(_PlacedOrder order, NumberFormat fmt) {
    final info = _statusInfo(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withAlpha(80)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(info.icon, color: info.color, size: 18),
          const SizedBox(width: 8),
          Text(info.label,
              style: TextStyle(color: info.color, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (order.isAddOn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _accent.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Add-on', style: TextStyle(color: _accent, fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 10),
        ...order.items.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Text('${c.qty}×', style: const TextStyle(color: _C.subtext, fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(child: Text(c.item.name,
                style: const TextStyle(color: _C.text, fontSize: 13))),
            Text(fmt.format(c.subtotal),
                style: const TextStyle(color: _C.subtext, fontSize: 12)),
          ]),
        )),
        const Divider(color: _C.divider, height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Order total', style: TextStyle(color: _C.subtext, fontSize: 12)),
          Text(fmt.format(order.subtotal),
              style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        // ── Cancel UI ─────────────────────────────────────────────────────
        if (order.status == 'pending') ...[
          const SizedBox(height: 10),
          _cancellingOrderId == order.id
              ? const Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2),
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelOrder(order),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel Order',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
        ] else if (order.status == 'preparing' || order.status == 'ready') ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.info_outline_rounded, color: _C.subtext, size: 14),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Food is being prepared — speak to a staff member to cancel.',
                style: TextStyle(color: _C.subtext, fontSize: 11),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _combinedInvoice(NumberFormat fmt) {
    final total = _orders.fold(0.0, (s, o) => s + o.subtotal);
    final tax = total * _taxRate;
    final service = total * _serviceRate;
    final grand = total + tax + service;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_orders.length > 1 ? 'Combined Bill' : 'Bill Summary',
            style: TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        _invoiceRow('Subtotal', fmt.format(total), fmt),
        if (_taxRate > 0) _invoiceRow('Tax', fmt.format(tax), fmt),
        if (_serviceRate > 0) _invoiceRow('Service Charge', fmt.format(service), fmt),
        const Divider(color: _C.divider, height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Grand Total', style: TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(fmt.format(grand), style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
      ]),
    );
  }

  Widget _invoiceRow(String label, String value, NumberFormat _) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
      Text(value, style: const TextStyle(color: _C.subtext, fontSize: 13)),
    ]),
  );

  ({String label, Color color, IconData icon}) _statusInfo(String status) {
    return switch (status) {
      'pending'   => (label: 'Received — your order is queued',  color: Colors.orange,    icon: Icons.hourglass_empty_rounded),
      'preparing' => (label: 'Preparing your order…',            color: Colors.blue,      icon: Icons.restaurant_rounded),
      'ready'     => (label: 'Ready — on its way to your room!', color: Colors.green,     icon: Icons.delivery_dining_rounded),
      'served'    => (label: 'Delivered — enjoy your meal!',     color: Colors.green,     icon: Icons.check_circle_rounded),
      'cancelled' => (label: 'Cancelled',                        color: Colors.redAccent, icon: Icons.cancel_rounded),
      _           => (label: status,                             color: _C.subtext,       icon: Icons.info_outline_rounded),
    };
  }

  // ── Feedback ──────────────────────────────────────────────────────────────────

  Widget _feedbackView() => Scaffold(
    backgroundColor: _C.bg,
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _logoWidget(64),
        const SizedBox(height: 20),
        const Text('How was your room service?',
            style: TextStyle(color: _C.text, fontSize: 20, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text('Your feedback helps us improve.',
            style: TextStyle(color: _C.subtext, fontSize: 13)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _feedbackRating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ['😞', '😕', '😐', '😊', '😍'][i],
                  style: TextStyle(fontSize: _feedbackRating == i + 1 ? 40 : 30),
                ),
              ),
            ))),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.divider),
          ),
          child: TextField(
            controller: _feedbackController,
            maxLines: 3,
            style: const TextStyle(color: _C.text, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Any comments? (optional)',
              hintStyle: TextStyle(color: _C.subtext, fontSize: 14),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: (_feedbackRating == 0 || _isSubmittingFeedback) ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent, foregroundColor: _C.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmittingFeedback
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: _C.bg, strokeWidth: 2))
                : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() { _showFeedback = false; _sessionEnded = true; }),
          child: const Text('Skip', style: TextStyle(color: _C.subtext, fontSize: 14)),
        ),
      ]),
    ))),
  );

  // ── Session ended ─────────────────────────────────────────────────────────────

  Widget _sessionEndedView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _logoWidget(80),
        const SizedBox(height: 24),
        Icon(Icons.check_circle_rounded, color: _accent, size: 56),
        const SizedBox(height: 16),
        const Text('Thank You!',
            style: TextStyle(color: _C.text, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Your order has been delivered.\nWe hope you enjoyed your meal!',
          style: TextStyle(color: _C.subtext, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.divider),
          ),
          child: const Row(children: [
            Icon(Icons.qr_code_scanner_rounded, color: _C.subtext, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(
              'Scan the QR code in your room again to place a new order.',
              style: TextStyle(color: _C.subtext, fontSize: 13),
            )),
          ]),
        ),
      ]),
    )),
  );
}

// ─── Cart bottom sheet ────────────────────────────────────────────────────────

class _CartSheet extends StatefulWidget {
  final List<_CartItem> cart;
  final double subtotal, tax, taxRate, serviceCharge, serviceRate, total;
  final bool isAddOn, isPlacing;
  final void Function(_CartItem) onAdd;
  final void Function(_CartItem) onRemove;
  final VoidCallback onPlace;
  final String currencySymbol;
  final Color accent;

  const _CartSheet({
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.taxRate,
    required this.serviceCharge,
    required this.serviceRate,
    required this.total,
    required this.isAddOn,
    required this.isPlacing,
    required this.onAdd,
    required this.onRemove,
    required this.onPlace,
    required this.currencySymbol,
    required this.accent,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: widget.currencySymbol, decimalDigits: 2);

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
          Center(child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(2)),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Text(widget.isAddOn ? 'Add-on Items' : 'Your Order',
                  style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${widget.cart.fold(0, (s, c) => s + c.qty)} items',
                  style: const TextStyle(color: _C.subtext, fontSize: 13)),
            ]),
          ),
          const Divider(color: _C.divider, height: 1),
          Expanded(child: ListView.builder(
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
                      onTap: () { widget.onRemove(c); setState(() {}); },
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: _C.card, borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.divider),
                        ),
                        child: const Icon(Icons.remove_rounded, color: _C.text, size: 14),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('${c.qty}',
                          style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    GestureDetector(
                      onTap: () { widget.onAdd(c); setState(() {}); },
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: _C.card, borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.divider),
                        ),
                        child: const Icon(Icons.add_rounded, color: _C.text, size: 14),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.item.name, style: const TextStyle(color: _C.text, fontSize: 14)),
                      if (c.selectedModifiers.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...c.selectedModifiers.entries.map((e) {
                          final counts = <String, int>{};
                          for (final n in e.value) { counts[n] = (counts[n] ?? 0) + 1; }
                          final summary = counts.entries.map((c2) => c2.value > 1 ? '${c2.key} ×${c2.value}' : c2.key).join(', ');
                          return Text('${e.key}: $summary', style: const TextStyle(color: _C.subtext, fontSize: 11));
                        }),
                      ],
                    ],
                  )),
                  Text(fmt.format(c.subtotal),
                      style: const TextStyle(color: _C.subtext, fontSize: 13)),
                ]),
              );
            },
          )),
          const Divider(color: _C.divider, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(children: [
              _row('Subtotal', fmt.format(widget.subtotal)),
              if (widget.taxRate > 0) _row('Tax', fmt.format(widget.tax)),
              if (widget.serviceRate > 0) _row('Service Charge', fmt.format(widget.serviceCharge)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(widget.isAddOn ? 'This order' : 'Total',
                    style: const TextStyle(color: _C.text, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(fmt.format(widget.total),
                    style: TextStyle(color: widget.accent, fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: widget.isPlacing ? null : widget.onPlace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent, foregroundColor: _C.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: widget.isPlacing
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: _C.bg, strokeWidth: 2))
                      : Text(widget.isAddOn ? 'Add to Order' : 'Place Order',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
      Text(value, style: const TextStyle(color: _C.subtext, fontSize: 13)),
    ]),
  );
}
