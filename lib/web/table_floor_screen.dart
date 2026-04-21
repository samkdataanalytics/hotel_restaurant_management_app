import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../providers/hotel_session.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../models/restaurant_table.dart';
import '../services/booking_service.dart';
import '../app_theme.dart';
import '../models/staff_permission.dart';
import '../services/restaurant_service.dart';
import 'restaurant_invoice_dialog.dart';

const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;
const _kGreen = Color(0xFF22C55E);
const _kGreenBg = Color(0xFFF0FFF4);

// ─── Payment result passed back from the dialog ──────────────────────────────

class _PaymentResult {
  final PaymentStatus paymentStatus;
  final String? bookingId;
  final String? roomId;
  final String? discountType;   // 'percentage' | 'flat' | null
  final double  discountAmount;
  const _PaymentResult({
    required this.paymentStatus,
    this.bookingId,
    this.roomId,
    this.discountType,
    this.discountAmount = 0.0,
  });
}

// ─── Payment Dialog ───────────────────────────────────────────────────────────

class _PaymentDialog extends StatefulWidget {
  final List<RestaurantOrder> orders;
  final RestaurantTable table;
  final BookingService bookingService;
  final NumberFormat currency;

  const _PaymentDialog({
    required this.orders,
    required this.table,
    required this.bookingService,
    required this.currency,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String? _method; // 'cash' | 'card' | 'room'
  List<Map<String, dynamic>> _checkedInGuests = [];
  bool _loadingGuests = false;
  Map<String, dynamic>? _selectedGuest; // the chosen entry {booking, guest, room}

  // Discount
  String _discountType   = 'percentage';
  double _discountAmount = 0.0;
  final  _discountCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCheckedInGuests();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCheckedInGuests() async {
    setState(() => _loadingGuests = true);
    final enriched = await widget.bookingService.getEnrichedCheckIns();
    if (!mounted) return;
    // Filter to only currently checked-in bookings
    final checkedIn = enriched.where((d) {
      final booking = d['booking'] as Booking?;
      return booking != null && booking.status == BookingStatus.checkedIn;
    }).toList();
    setState(() {
      _checkedInGuests = checkedIn;
      _loadingGuests = false;
    });
  }

  bool get _canConfirm {
    if (_method == null) return false;
    if (_method == 'room' && _selectedGuest == null) return false;
    return true;
  }

  void _confirm() {
    PaymentStatus status;
    String? bookingId;
    String? roomId;
    if (_method == 'room') {
      status = PaymentStatus.chargedToRoom;
      final b = _selectedGuest!['booking'] as Booking;
      bookingId = b.id;
      roomId = b.roomId;
    } else {
      status = PaymentStatus.paid;
    }
    Navigator.pop(
        context,
        _PaymentResult(
            paymentStatus:  status,
            bookingId:      bookingId,
            roomId:         roomId,
            discountType:   _discountAmount > 0 ? _discountType : null,
            discountAmount: _discountAmount));
  }

  Widget _discountToggleBtn(String label, String value) {
    final active = _discountType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _discountType = value;
        final raw = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
        final total = widget.orders.fold(0.0, (s, o) => s + o.itemsTotal);
        _discountAmount = value == 'percentage'
            ? raw.clamp(0.0, 100.0)
            : raw.clamp(0.0, total);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _methodTile(IconData icon, String label, String value, Color color) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _method = value;
          if (value != 'room') _selectedGuest = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.black38, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate           = settings?.taxRate           ?? 0.0;
    final serviceChargeRate = settings?.serviceChargeRate ?? 0.0;

    final itemsTotal = widget.orders.fold(0.0, (s, o) => s + o.itemsTotal);
    final discountValue = _discountAmount <= 0
        ? 0.0
        : _discountType == 'percentage'
            ? itemsTotal * (_discountAmount / 100)
            : _discountAmount;
    final subtotal      = (itemsTotal - discountValue).clamp(0.0, double.infinity);
    final tax           = subtotal * taxRate;
    final serviceCharge = subtotal * serviceChargeRate;
    final total         = subtotal + tax + serviceCharge;
    final orderNumbers  = widget.orders.map((o) => '#${o.orderNumber}').join(' + ');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.payment_rounded, color: _kGreen, size: 22),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Collect Payment',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                          'Table ${widget.table.tableNumber}  ·  $orderNumbers',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black38)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                        foregroundColor: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Discount input ──────────────────────────────────────
              const Text('Apply Discount',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
              const SizedBox(height: 8),
              Row(children: [
                // % / Flat toggle
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _discountToggleBtn('%',    'percentage'),
                    _discountToggleBtn('Flat', 'flat'),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _discountType == 'percentage' ? 'Discount %' : 'Discount amount',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                        suffixText: _discountType == 'percentage' ? '%' : null,
                      ),
                      onChanged: (v) => setState(() {
                        final raw = double.tryParse(v.trim()) ?? 0.0;
                        final total = widget.orders.fold(0.0, (s, o) => s + o.itemsTotal);
                        _discountAmount = _discountType == 'percentage'
                            ? raw.clamp(0.0, 100.0)
                            : raw.clamp(0.0, total);
                      }),
                    ),
                  ),
                ),
                if (_discountAmount > 0) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => setState(() {
                      _discountAmount = 0.0;
                      _discountCtrl.clear();
                    }),
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              // ── Amount summary ───────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kOrangeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items   ${widget.currency.format(itemsTotal)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (discountValue > 0)
                          Text(
                            'Discount   − ${widget.currency.format(discountValue)}',
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        Text('Tax (${(taxRate * 100).toStringAsFixed(0)}%)   ${widget.currency.format(tax)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        if (serviceChargeRate > 0)
                          Text('Service   ${widget.currency.format(serviceCharge)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('TOTAL DUE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.black38)),
                        Text(widget.currency.format(total),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _kOrange)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment method
              const Text('Select payment method',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black45)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _methodTile(Icons.money_rounded, 'Cash', 'cash',
                      Colors.green.shade600),
                  const SizedBox(width: 10),
                  _methodTile(Icons.credit_card_rounded, 'Card', 'card',
                      Colors.blue.shade600),
                  const SizedBox(width: 10),
                  _methodTile(Icons.hotel_rounded, 'Room Charge', 'room',
                      _kOrange),
                ],
              ),

              // Room charge — checked-in guest list
              if (_method == 'room') ...[
                const SizedBox(height: 16),
                const Text('Select checked-in guest',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _loadingGuests
                      ? const Center(child: CircularProgressIndicator())
                      : _checkedInGuests.isEmpty
                          ? const Center(
                              child: Text('No guests currently checked in',
                                  style: TextStyle(
                                      color: Colors.black38, fontSize: 13)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(6),
                              itemCount: _checkedInGuests.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = _checkedInGuests[i];
                                final booking = d['booking'] as Booking;
                                final guest = d['guest'] as Guest;
                                final room = d['room'] as Room?;
                                final isSelected = _selectedGuest == d;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedColor: _kOrange,
                                  selectedTileColor:
                                      _kOrange.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        _kOrange.withOpacity(0.1),
                                    child: const Icon(Icons.person_rounded,
                                        size: 16, color: _kOrange),
                                  ),
                                  title: Text(
                                    guest.fullName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    'Room ${room?.roomNumber ?? "N/A"}  ·  Ref: ${booking.bookingRef}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _kOrange,
                                          size: 18)
                                      : null,
                                  onTap: () =>
                                      setState(() => _selectedGuest = d),
                                );
                              },
                            ),
                ),
                if (_selectedGuest != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kGreenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 15, color: _kGreen),
                        const SizedBox(width: 8),
                        Text(
                          'Charging to: ${(_selectedGuest!['guest'] as Guest).fullName}'
                          '  ·  Room ${(_selectedGuest!['room'] as Room?)?.roomNumber ?? "—"}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Confirm
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canConfirm ? _confirm : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Confirm Payment & Close Table',
                      style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade100,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Table Floor Screen ───────────────────────────────────────────────────────

class TableFloorScreen extends ConsumerStatefulWidget {
  const TableFloorScreen({super.key});

  @override
  ConsumerState<TableFloorScreen> createState() => _TableFloorScreenState();
}

class _TableFloorScreenState extends ConsumerState<TableFloorScreen> {
  final _service = RestaurantService();
  final _bookingService = BookingService();
  final _uuid = const Uuid();
  NumberFormat get _currency => NumberFormat.currency(
      symbol: pkg_provider.Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);

  // ── Data
  List<RestaurantTable> _tables = [];
  /// tableId → all open (unpaid, non-cancelled) orders, oldest first
  Map<String, List<RestaurantOrder>> _allTableOrders = {};
  List<MenuItem> _menuItems = [];
  List<String> _categories = [];

  // ── UI state
  bool _isLoading = true;
  String? _selectedTableId;
  bool _isAddingItems = false;
  bool _isProcessing = false;
  
  // ── Realtime
  Timer? _refreshTimer;
  RealtimeChannel? _realtimeChannel;

  // ── Item picker state
  String? _selectedCategory; // null = All
  final List<OrderItem> _addCart = []; 
  String _itemSearchQuery = '';
  final _itemSearchController = TextEditingController();

  int _findCartItemIndex(MenuItem item, Map<String, List<String>> mods) {
    return _addCart.indexWhere((e) {
      if (e.menuItem.id != item.id) return false;
      if (e.selectedModifiers.length != mods.length) return false;
      for (final k in mods.keys) {
        if (!e.selectedModifiers.containsKey(k)) return false;
        final listA = List<String>.from(e.selectedModifiers[k]!)..sort();
        final listB = List<String>.from(mods[k]!)..sort();
        if (listA.join('|') != listB.join('|')) return false;
      }
      return true;
    });
  }

  void _addToCart(MenuItem item, {Map<String, List<String>>? selectedModifiers}) {
    if (!item.isAvailable || !canEditSection(ref, 'restaurant_tables')) return;
    if (item.modifiers.isNotEmpty && selectedModifiers == null) {
      _showModifierDialog(item);
      return;
    }
    final mods = selectedModifiers ?? {};
    setState(() {
      final idx = _findCartItemIndex(item, mods);
      if (idx >= 0) {
        _addCart[idx].quantity++;
      } else {
        _addCart.add(OrderItem(
          id: _uuid.v4(),
          menuItem: item,
          quantity: 1,
          selectedModifiers: mods,
        ));
      }
    });
  }

  void _removeFromCart(MenuItem item) {
    if (!item.isAvailable || !canEditSection(ref, 'restaurant_tables')) return;
    setState(() {
      final idx = _addCart.lastIndexWhere((e) => e.menuItem.id == item.id);
      if (idx >= 0) {
        if (_addCart[idx].quantity > 1) {
          _addCart[idx].quantity--;
        } else {
          _addCart.removeAt(idx);
        }
      }
    });
  }

  Future<void> _showModifierDialog(MenuItem item) async {
    final Map<String, List<String>> selections = {};
    for (final mod in item.modifiers) {
      selections[mod.name] = [];
    }
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Customize ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                Text(mod.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                if (mod.isRequired)
                                  const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text(mod.allowMultiple ? '(Qty per option)' : '(Choose 1)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...mod.options.map((opt) {
                              final priceLabel = opt.priceAdjustment == 0
                                  ? _currency.format(item.price)
                                  : '+${_currency.format(opt.priceAdjustment)}';
                              if (mod.allowMultiple) {
                                final optQty = selections[mod.name]!.where((n) => n == opt.name).length;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(opt.name, style: const TextStyle(fontSize: 14))),
                                      Text(priceLabel,
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      const SizedBox(width: 12),
                                      _qtyDialogBtn(
                                        icon: Icons.remove_rounded,
                                        enabled: optQty > 0,
                                        onTap: () => setSt(() => selections[mod.name]!.remove(opt.name)),
                                      ),
                                      SizedBox(
                                        width: 36,
                                        child: Text('$optQty',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: optQty > 0 ? _kOrange : Colors.black26)),
                                      ),
                                      _qtyDialogBtn(
                                        icon: Icons.add_rounded,
                                        enabled: true,
                                        onTap: () => setSt(() => selections[mod.name]!.add(opt.name)),
                                      ),
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
                                          color: isSelected ? _kOrange : Colors.grey.shade400,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(opt.name, style: const TextStyle(fontSize: 14))),
                                        Text(priceLabel,
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                    const Divider(),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('Quantity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        _qtyDialogBtn(icon: Icons.remove_rounded, enabled: qty > 1, onTap: () => setSt(() => qty--)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        _qtyDialogBtn(icon: Icons.add_rounded, enabled: true, onTap: () => setSt(() => qty++)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isValid ? () => Navigator.pop(ctx, (mods: selections, qty: qty)) : null,
                style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white),
                child: Text('Add $qty to Order'),
              )
            ],
          );
        }
      )
    );

    if (result != null) {
      for (int i = 0; i < result.qty; i++) {
        _addToCart(item, selectedModifiers: result.mods);
      }
    }
  }

  Widget _qtyDialogBtn({required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? _kOrange.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: enabled ? _kOrange : Colors.grey.shade400),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _load(silent: true));
    
    _realtimeChannel = Supabase.instance.client
        .channel('tables_orders_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurant_orders',
          callback: (_) => _load(silent: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'restaurant_tables',
          callback: (_) => _load(silent: true),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final tables = await _service.getTables();
    final orders = await _service.getOrders();
    final menuItems = await _service.getMenuItems();

    // Build map of tableId → all open (unpaid, non-cancelled) orders oldest-first
    final allTableOrders = <String, List<RestaurantOrder>>{};
    final staleOrderIds = <String>[]; // fully-refunded ghosts to auto-cancel
    for (final o in orders) {
      if (o.tableId == null) continue;
      if (o.status == OrderStatus.cancelled) continue;
      if (o.paymentStatus == PaymentStatus.paid ||
          o.paymentStatus == PaymentStatus.chargedToRoom) {
        continue;
      }
      // Skip orders where every item has been fully refunded ($0 ghosts)
      if (o.items.isNotEmpty && o.items.every((i) => i.isFullyRefunded)) {
        staleOrderIds.add(o.id);
        continue;
      }
      allTableOrders.putIfAbsent(o.tableId!, () => []).add(o);
    }
    for (final list in allTableOrders.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    // Auto-cancel stale fully-refunded orders in background
    for (final id in staleOrderIds) {
      _service.cancelOrder(id).catchError((_) {});
    }

    final cats =
        menuItems.map((m) => m.category).toSet().toList()..sort();

    if (!mounted) return;
    setState(() {
      _tables = tables
        ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
      _allTableOrders = allTableOrders;
      _menuItems = menuItems;
      _categories = cats;
      _isLoading = false;
    });
  }

  // ── Selection

  void _selectTable(RestaurantTable table) {
    final hasOpenTab = _allTableOrders.containsKey(table.id);
    setState(() {
      _selectedTableId = table.id;
      _isAddingItems = !hasOpenTab; // available → open item picker immediately
      _addCart.clear();
      _itemSearchQuery = '';
      _itemSearchController.clear();
    });
  }

  // ── Confirm items (open new tab or add to existing)

  Future<void> _confirmAddItems() async {
    if (_addCart.isEmpty || _selectedTableId == null) return;
    setState(() => _isProcessing = true);

    try {
      final newItems = List<OrderItem>.from(_addCart);

      final openOrders = _allTableOrders[_selectedTableId!];
      final latestOrder = openOrders?.isNotEmpty == true ? openOrders!.last : null;
      RestaurantOrder updated;

      final isInKitchen = latestOrder != null &&
          (latestOrder.status == OrderStatus.preparing ||
              latestOrder.status == OrderStatus.ready ||
              latestOrder.status == OrderStatus.served);

      if (latestOrder == null || isInKitchen) {
        // New tab OR add-on when latest order is already in-kitchen/served.
        // Link to the root parent so all add-ons share one parent.
        final parentId = latestOrder == null
            ? null
            : (latestOrder.parentOrderId ?? latestOrder.id);
        updated = await _service.createTableOrder(
            tableId: _selectedTableId!, items: newItems, parentOrderId: parentId);
      } else {
        // Latest order is still pending — append items to it
        updated = await _service.addItemsToOrder(latestOrder.id, newItems);
      }

      await _load();
      if (!mounted) return;
      setState(() {
        _selectedTableId = updated.tableId;
        _isAddingItems = false;
        _addCart.clear();
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Collect payment (settles all open orders for the table at once)

  Future<void> _collectPayment(
      List<RestaurantOrder> openOrders, RestaurantTable table) async {
    final result = await showDialog<_PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        orders: openOrders,
        table: table,
        bookingService: _bookingService,
        currency: _currency,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // Apply discount to the first (parent) order if one was entered
      List<RestaurantOrder> updatedOrders = List.from(openOrders);
      if (result.discountType != null && result.discountAmount > 0) {
        final first = openOrders.first;
        await _service.updateOrderDiscount(
          orderId: first.id,
          discountType: result.discountType!,
          discountAmount: result.discountAmount,
        );
        updatedOrders = [
          first.copyWith(
            discountType:   result.discountType,
            discountAmount: result.discountAmount,
          ),
          ...openOrders.skip(1),
        ];
      }

      final settledOrders = await _service.settleAllTableOrders(
        tableId: table.id,
        paymentStatus: result.paymentStatus,
        bookingId: result.bookingId,
        roomId: result.roomId,
      );

      if (!mounted) return;
      // Show combined invoice — use updatedOrders so discount is reflected
      if (updatedOrders.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (_) => RestaurantInvoiceDialog(
            order: updatedOrders.first,
            table: table,
            allOrders: updatedOrders.length > 1 ? updatedOrders : null,
          ),
        );
      }
      await _load();
      if (!mounted) return;
      setState(() {
        _selectedTableId = null;
        _isAddingItems = false;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Table grid
                Container(
                  width: 380,
                  color: const Color(0xFFF8FAFC),
                  child: _buildTableGrid(),
                ),
                Container(width: 1, color: Colors.grey.shade200),
                // Right: Detail panel
                Expanded(child: _buildDetailPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────

  Widget _buildHeader() {
    final available =
        _tables.where((t) => t.status == TableStatus.available).length;
    final occupied =
        _tables.where((t) => t.status == TableStatus.occupied).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: _kOrangeBg, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.table_restaurant_rounded,
                color: _kOrange, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Table Floor',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(width: 20),
          _statPill(Icons.check_circle_outline, '$available Available',
              Colors.green.shade600),
          const SizedBox(width: 8),
          _statPill(Icons.people_rounded, '$occupied Occupied', _kOrange),
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

  Widget _statPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─── Left panel: Table Grid ───────────────────────────

  Widget _buildTableGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Tap a table to manage',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ),
        Expanded(
          child: _tables.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant_rounded,
                          color: Colors.grey, size: 48),
                      SizedBox(height: 12),
                      Text('No tables configured',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Add tables in Restaurant Management',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _tables.length,
                  itemBuilder: (_, i) => _buildTableCard(_tables[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildTableCard(RestaurantTable table) {
    final openOrders = _allTableOrders[table.id];
    final isOccupied = openOrders != null && openOrders.isNotEmpty;
    final isSelected = _selectedTableId == table.id;

    // Use the oldest order's createdAt for elapsed time (session start)
    int elapsedMinutes = 0;
    String timeLabel = '';
    if (isOccupied) {
      final elapsed = DateTime.now().difference(openOrders.first.createdAt);
      elapsedMinutes = elapsed.inMinutes;
      timeLabel = elapsedMinutes < 60
          ? '${elapsedMinutes}m'
          : '${elapsed.inHours}h ${elapsedMinutes % 60}m';
    }

    Color timeBadgeBgColor = Colors.green.shade50;
    Color timeBadgeTextColor = Colors.green.shade700;
    if (isOccupied) {
      if (elapsedMinutes >= 30) {
        timeBadgeBgColor = Colors.red.shade50;
        timeBadgeTextColor = Colors.red.shade700;
      } else if (elapsedMinutes >= 15) {
        timeBadgeBgColor = Colors.orange.shade50;
        timeBadgeTextColor = Colors.orange.shade700;
      }
    }

    final cardColor = isSelected
        ? (isOccupied ? _kOrangeBg : _kGreenBg)
        : Colors.white;
    final borderColor = isSelected
        ? (isOccupied ? _kOrange : _kGreen)
        : isOccupied
            ? _kOrange.withOpacity(0.25)
            : Colors.grey.shade200;

    return GestureDetector(
      onTap: () => _selectTable(table),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (isOccupied ? _kOrange : _kGreen).withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? _kOrange.withOpacity(0.12)
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      isOccupied
                          ? Icons.people_rounded
                          : Icons.table_restaurant_rounded,
                      size: 15,
                      color: isOccupied ? _kOrange : Colors.green.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (isOccupied)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: timeBadgeBgColor,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(timeLabel,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: timeBadgeTextColor)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Table ${table.tableNumber}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isOccupied ? Colors.black87 : Colors.black45)),
              Text('Cap: ${table.capacity}',
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const Spacer(),
              if (isOccupied) ...[
                Text(
                  '${openOrders.fold(0, (s, o) => s + o.items.fold(0, (s2, i) => s2 + i.activeQuantity))} item(s)'
                  '${openOrders.length > 1 ? " · ${openOrders.length} tickets" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  _currency.format(
                      openOrders.fold(0.0, (s, o) => s + o.totalAmount)),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kOrange),
                ),
              ] else ...[
                Text('Available',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600)),
                Text('Tap to start order',
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Right panel router ───────────────────────────────

  Widget _buildDetailPanel() {
    Widget content;
    if (_selectedTableId == null) {
      content = _buildIdleState();
    } else if (_isAddingItems) {
      content = _buildItemPickerPanel();
    } else {
      final openOrders = _allTableOrders[_selectedTableId!];
      if (openOrders == null || openOrders.isEmpty) {
        content = _buildIdleState();
      } else {
        final table = _tables.firstWhere((t) => t.id == _selectedTableId);
        content = _buildOrderPanel(openOrders, table);
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey('$_selectedTableId-$_isAddingItems'),
        child: content,
      ),
    );
  }

  Widget _buildIdleState() {
    final activeTabs = _allTableOrders.values.where((l) => l.isNotEmpty).length;
    final totalRevenue = _allTableOrders.values.fold<double>(
        0, (sum, orders) => sum + orders.fold(0, (s, o) => s + o.totalAmount));

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, size: 48, color: Color(0xFFE65100)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Shift Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap an available table to start a new order,\nor an occupied table to manage the tab.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('Active Tabs', activeTabs.toString()),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  _buildStatColumn('Open Revenue', _currency.format(totalRevenue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      ],
    );
  }

  // ─── Order view ───────────────────────────────────────

  Widget _buildOrderPanel(List<RestaurantOrder> openOrders, RestaurantTable table) {
    final settings = pkg_provider.Provider.of<HotelSession>(context, listen: false).settings;
    final taxRate = settings?.taxRate ?? 0.0;
    final serviceChargeRate = settings?.serviceChargeRate ?? 0.0;
    final subtotal = openOrders.fold(0.0, (s, o) => s + o.totalAmount);
    final tax = subtotal * taxRate;
    final serviceCharge = subtotal * serviceChargeRate;
    final total = subtotal + tax + serviceCharge;
    final totalItems = openOrders.fold(
        0, (s, o) => s + o.items.fold(0, (s2, i) => s2 + i.activeQuantity));
    final elapsed = DateTime.now().difference(openOrders.first.createdAt);
    final timeStr = elapsed.inMinutes < 60
        ? '${elapsed.inMinutes} min'
        : '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Panel header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
          color: Colors.white,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Table ${table.tableNumber}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      _pill(timeStr, Colors.orange.shade700,
                          Colors.orange.shade50,
                          icon: Icons.timer_outlined),
                      const SizedBox(width: 6),
                      _pill('UNPAID', Colors.red.shade500,
                          Colors.red.shade50),
                      if (openOrders.length > 1) ...[
                        const SizedBox(width: 6),
                        _pill('${openOrders.length} TICKETS',
                            Colors.purple.shade600, Colors.purple.shade50),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${openOrders.map((o) => "#${o.orderNumber}").join(" + ")}  ·  $totalItems item(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const Spacer(),
              // Action buttons
              _actionBtn(Icons.add_rounded, 'Add Items', _kOrange,
                  outlined: true,
                  onPressed: () => setState(() {
                        _isAddingItems = true;
                        _addCart.clear();
                      })),
              const SizedBox(width: 8),
              _actionBtn(Icons.receipt_outlined, 'Print Bill', Colors.black54,
                  outlined: true,
                  onPressed: () => showDialog(
                        context: context,
                        builder: (_) => RestaurantInvoiceDialog(
                            order: openOrders.last, 
                            table: table,
                            allOrders: openOrders.length > 1 ? openOrders : null),
                      )),
              const SizedBox(width: 8),
              _actionBtn(Icons.payment_rounded, 'Collect Payment', _kGreen,
                  onPressed: _isProcessing || !canEditSection(ref, 'restaurant_tables')
                      ? null
                      : () => _collectPayment(openOrders, table)),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Items list — all orders, with ticket sub-headers when multiple
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _buildOrderItemList(openOrders).length,
            itemBuilder: (_, i) => _buildOrderItemList(openOrders)[i],
          ),
        ),

        // ── Totals footer
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border:
                Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              _totalRow('Subtotal', _currency.format(subtotal)),
              if (taxRate > 0) ...[
                const SizedBox(height: 5),
                _totalRow('Tax (${(taxRate * 100).toStringAsFixed(0)}%)', _currency.format(tax), muted: true),
              ],
              if (serviceChargeRate > 0) ...[
                const SizedBox(height: 5),
                _totalRow('Service (${(serviceChargeRate * 100).toStringAsFixed(0)}%)', _currency.format(serviceCharge), muted: true),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _kOrangeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL DUE',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(_currency.format(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: _kOrange)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the flat widget list for all items across all open orders.
  /// Inserts a ticket sub-header between orders when there are multiple tickets.
  List<Widget> _buildOrderItemList(List<RestaurantOrder> orders) {
    final widgets = <Widget>[];
    for (var idx = 0; idx < orders.length; idx++) {
      final order = orders[idx];
      if (orders.length > 1) {
        final isChild = order.parentOrderId != null;
        widgets.add(Padding(
          padding: EdgeInsets.only(
              bottom: 6, top: idx == 0 ? 0 : 12),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isChild
                      ? Colors.teal.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isChild
                      ? 'Add-On #${order.orderNumber}'
                      : 'Ticket #${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isChild
                        ? Colors.teal.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusLabelShort(order.status),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
        ));
      }
      for (final item in order.items) {
        widgets.add(_buildOrderItemRow(item));
      }
    }
    return widgets;
  }

  String _statusLabelShort(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'In Kitchen';
      case OrderStatus.ready:
        return 'Ready to Serve';
      case OrderStatus.served:
        return 'Served';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Widget _buildOrderItemRow(OrderItem item) {
    final fullyRefunded = item.isFullyRefunded;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: fullyRefunded ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
              item.menuItem.imageUrl.isNotEmpty
                  ? item.menuItem.imageUrl
                  : '🍽️',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.menuItem.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: fullyRefunded
                            ? TextDecoration.lineThrough
                            : null,
                        color: fullyRefunded
                            ? Colors.grey.shade400
                            : Colors.black87)),
                ...item.selectedModifiers.entries
                    .where((e) => e.value.isNotEmpty)
                    .map((e) {
                      final counts = <String, int>{};
                      for (final n in e.value) {
                        counts[n] = (counts[n] ?? 0) + 1;
                      }
                      final summary = counts.entries.map((c) => c.value > 1 ? '${c.key} ×${c.value}' : c.key).join(', ');
                      return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Text('${e.key}: ',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600)),
                              Flexible(
                                child: Text(summary,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade700)),
                              ),
                            ],
                          ),
                        );
                    }),
                if (item.notes.isNotEmpty)
                  Text(item.notes,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                if (item.refundedQuantity > 0 && !fullyRefunded)
                  Text('${item.refundedQuantity} unit(s) refunded',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade600)),
              ],
            ),
          ),
          Text('×${item.activeQuantity}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          const SizedBox(width: 16),
          SizedBox(
            width: 72,
            child: Text(_currency.format(item.subtotal),
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fullyRefunded
                        ? Colors.grey.shade400
                        : Colors.black87)),
          ),
        ],
      ),
    );
  }

  // ─── Item picker panel ────────────────────────────────

  Widget _buildItemPickerPanel() {
    final table = _tables.firstWhere((t) => t.id == _selectedTableId);
    final isNewTab = !_allTableOrders.containsKey(_selectedTableId!);
    final existingOrderForPicker = _allTableOrders[_selectedTableId!]?.lastOrNull;
    final isAddOn = existingOrderForPicker != null &&
        (existingOrderForPicker.status == OrderStatus.preparing ||
            existingOrderForPicker.status == OrderStatus.ready ||
            existingOrderForPicker.status == OrderStatus.served);
    var filteredItems = _selectedCategory == null
        ? _menuItems
        : _menuItems.where((m) => m.category == _selectedCategory).toList();
    // Apply search filter
    if (_itemSearchQuery.isNotEmpty) {
      final q = _itemSearchQuery.toLowerCase();
      filteredItems = filteredItems
          .where((m) => m.name.toLowerCase().contains(q))
          .toList();
    }
    final cartCount = _addCart.fold(0, (s, v) => s + v.quantity);
    final cartTotal = _addCart.fold(0.0, (s, e) => s + e.subtotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 12, 24, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _isAddingItems = false;
                  _addCart.clear();
                  if (isNewTab) _selectedTableId = null;
                }),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(foregroundColor: Colors.black54),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAddOn
                        ? 'Add-On Order — Table ${table.tableNumber}'
                        : isNewTab
                            ? 'New Order — Table ${table.tableNumber}'
                            : 'Add to Tab — Table ${table.tableNumber}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    isAddOn
                        ? 'Creates a new separate kitchen ticket'
                        : isNewTab
                            ? 'Select items to open the tab'
                            : 'Select items to add to the running tab',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search bar + Category chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Column(
            children: [
              // Search bar
              SizedBox(
                height: 38,
                child: TextField(
                  controller: _itemSearchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search menu items…',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.grey.shade400),
                    suffixIcon: _itemSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
                            onPressed: () => setState(() {
                              _itemSearchQuery = '';
                              _itemSearchController.clear();
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _itemSearchQuery = v.trim()),
                ),
              ),
              const SizedBox(height: 10),
              // Category chips with 'All'
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 'All' chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('All',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedCategory == null
                                    ? Colors.white
                                    : Colors.black54)),
                        selected: _selectedCategory == null,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = null),
                        selectedColor: _kOrange,
                        backgroundColor: Colors.grey.shade100,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ..._categories.map((cat) {
                      final sel = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : Colors.black54)),
                          selected: sel,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                          selectedColor: _kOrange,
                          backgroundColor: Colors.grey.shade100,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Item grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (_, i) => _buildMenuCard(filteredItems[i]),
          ),
        ),

        // Cart footer
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              if (cartCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: _kOrangeBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '$cartCount item${cartCount == 1 ? '' : 's'}  ·  ${_currency.format(cartTotal)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kOrange),
                  ),
                )
              else
                Text('No items selected',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _isAddingItems = false;
                  _addCart.clear();
                  if (isNewTab) _selectedTableId = null;
                }),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed:
                    cartCount > 0 && !_isProcessing && canEditSection(ref, 'restaurant_tables') ? _confirmAddItems : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(
                        isAddOn
                            ? Icons.send_rounded
                            : Icons.check_rounded,
                        size: 16),
                label: Text(isAddOn
                    ? 'Send to Kitchen'
                    : isNewTab
                        ? 'Open Tab'
                        : 'Add to Tab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isAddOn ? const Color(0xFF0D9488) : _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(MenuItem item) {
    final unavailable = !item.isAvailable;
    final qty = _addCart.where((e) => e.menuItem.id == item.id).fold(0, (s, e) => s + e.quantity);
    final inCart = qty > 0;

    return Opacity(
      opacity: unavailable ? 0.45 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: unavailable
                  ? Colors.grey.shade300
                  : inCart
                      ? _kOrange
                      : Colors.grey.shade200,
              width: inCart && !unavailable ? 2 : 1),
          boxShadow: unavailable
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      item.imageUrl.isNotEmpty ? item.imageUrl : '🍽️',
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text(
                      unavailable
                          ? 'Unavailable'
                          : _currency.format(item.price),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: unavailable
                              ? Colors.red.shade400
                              : Colors.grey.shade600)),
                  if (item.modifiers.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Divider(height: 1, thickness: 0.8),
                    ),
                    ...item.modifiers.take(2).map((mod) {
                      final optLabels = mod.options.map((o) => o.priceAdjustment != 0
                          ? '${o.name} (+${_currency.format(o.priceAdjustment)})'
                          : o.name).join('  ·  ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mod.name,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500)),
                            const SizedBox(height: 2),
                            Text(optLabels,
                                style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    }),
                    if (item.modifiers.length > 2)
                      Text('+${item.modifiers.length - 2} more groups',
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                  ],
                  const SizedBox(height: 8),
                  // Qty stepper — disabled when unavailable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stepBtn(
                        icon: Icons.remove_rounded,
                        enabled: !unavailable && qty > 0,
                        onTap: () => _removeFromCart(item),
                      ),
                      Text('$qty',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: qty > 0 ? _kOrange : Colors.black26)),
                      _stepBtn(
                        icon: Icons.add_rounded,
                        enabled: !unavailable,
                        onTap: () => _addToCart(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // "OFF" badge
            if (unavailable)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('OFF',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: enabled ? _kOrange.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon,
            size: 14,
            color: enabled ? _kOrange : Colors.grey.shade300),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  Widget _pill(String label, Color color, Color bg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color,
      {bool outlined = false, VoidCallback? onPressed}) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade200,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );

    return outlined
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : ElevatedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _totalRow(String label, String value, {bool muted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: muted ? Colors.grey.shade400 : Colors.grey.shade600)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted ? Colors.grey.shade400 : Colors.black87)),
      ],
    );
  }
}
