import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../models/menu_item.dart';
import '../models/restaurant_order.dart';
import '../models/restaurant_table.dart';
import '../services/booking_service.dart';
import '../app_theme.dart';
import '../services/restaurant_service.dart';
import 'pos_screen.dart'; // RestaurantInvoiceDialog

const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;
const _kGreen = Color(0xFF22C55E);
const _kGreenBg = Color(0xFFF0FFF4);

// ─── Payment result passed back from the dialog ──────────────────────────────

class _PaymentResult {
  final PaymentStatus paymentStatus;
  final String? bookingId;
  final String? roomId;
  const _PaymentResult(
      {required this.paymentStatus, this.bookingId, this.roomId});
}

// ─── Payment Dialog ───────────────────────────────────────────────────────────

class _PaymentDialog extends StatefulWidget {
  final RestaurantOrder order;
  final RestaurantTable table;
  final BookingService bookingService;
  final NumberFormat currency;

  const _PaymentDialog({
    required this.order,
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

  @override
  void initState() {
    super.initState();
    _loadCheckedInGuests();
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
            paymentStatus: status,
            bookingId: bookingId,
            roomId: roomId));
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
    final subtotal = widget.order.totalAmount;
    final tax = subtotal * 0.08;
    final total = subtotal + tax;

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
                          'Table ${widget.table.tableNumber}  ·  Order #${widget.order.orderNumber}',
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

              // Amount summary
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
                        Text(
                            'Subtotal   ${widget.currency.format(subtotal)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        Text('Tax (8%)   ${widget.currency.format(tax)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
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

class TableFloorScreen extends StatefulWidget {
  const TableFloorScreen({super.key});

  @override
  State<TableFloorScreen> createState() => _TableFloorScreenState();
}

class _TableFloorScreenState extends State<TableFloorScreen> {
  final _service = RestaurantService();
  final _bookingService = BookingService();
  final _uuid = const Uuid();
  final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // ── Data
  List<RestaurantTable> _tables = [];
  Map<String, RestaurantOrder> _tabOrders = {}; // tableId → active unpaid order
  List<MenuItem> _menuItems = [];
  List<String> _categories = [];

  // ── UI state
  bool _isLoading = true;
  String? _selectedTableId;
  bool _isAddingItems = false;
  bool _isProcessing = false;

  // ── Item picker state
  String? _selectedCategory;
  final Map<String, int> _addCart = {}; // menuItemId → qty

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final tables = await _service.getTables();
    final orders = await _service.getOrders();
    final menuItems = await _service.getMenuItems();

    // Active tab = dine-in order that is not yet served/cancelled and still unpaid
    final tabOrders = <String, RestaurantOrder>{};
    for (final o in orders) {
      if (o.tableId == null) continue;
      if (o.status == OrderStatus.cancelled || o.status == OrderStatus.served)
        continue;
      if (o.paymentStatus == PaymentStatus.paid ||
          o.paymentStatus == PaymentStatus.chargedToRoom) continue;
      final existing = tabOrders[o.tableId!];
      if (existing == null || o.createdAt.isAfter(existing.createdAt)) {
        tabOrders[o.tableId!] = o;
      }
    }

    final cats =
        menuItems.map((m) => m.category).toSet().toList()..sort();

    if (!mounted) return;
    setState(() {
      _tables = tables
        ..sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
      _tabOrders = tabOrders;
      _menuItems = menuItems;
      _categories = cats;
      _selectedCategory ??= cats.isNotEmpty ? cats.first : null;
      _isLoading = false;
    });
  }

  // ── Selection

  void _selectTable(RestaurantTable table) {
    final hasOpenTab = _tabOrders.containsKey(table.id);
    setState(() {
      _selectedTableId = table.id;
      _isAddingItems = !hasOpenTab; // available → open item picker immediately
      _addCart.clear();
    });
  }

  // ── Confirm items (open new tab or add to existing)

  Future<void> _confirmAddItems() async {
    if (_addCart.isEmpty || _selectedTableId == null) return;
    setState(() => _isProcessing = true);

    try {
      final newItems = _addCart.entries
          .where((e) => e.value > 0)
          .map((e) {
            final menuItem = _menuItems.firstWhere((m) => m.id == e.key);
            return OrderItem(
                id: _uuid.v4(), menuItem: menuItem, quantity: e.value);
          })
          .toList();

      final existingOrder = _tabOrders[_selectedTableId!];
      RestaurantOrder updated;

      if (existingOrder == null) {
        updated = await _service.createTableOrder(
            tableId: _selectedTableId!, items: newItems);
      } else {
        updated =
            await _service.addItemsToOrder(existingOrder.id, newItems);
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

  // ── Collect payment

  Future<void> _collectPayment(
      RestaurantOrder order, RestaurantTable table) async {
    final result = await showDialog<_PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentDialog(
        order: order,
        table: table,
        bookingService: _bookingService,
        currency: _currency,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final paid = await _service.collectTablePayment(
        orderId: order.id,
        paymentStatus: result.paymentStatus,
        bookingId: result.bookingId,
        roomId: result.roomId,
      );

      if (!mounted) return;
      // Show invoice
      await showDialog(
        context: context,
        builder: (_) => RestaurantInvoiceDialog(order: paid, table: table),
      );
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
          child: GridView.builder(
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
    final order = _tabOrders[table.id];
    final isOccupied = order != null;
    final isSelected = _selectedTableId == table.id;

    String timeLabel = '';
    if (isOccupied) {
      final elapsed = DateTime.now().difference(order.createdAt);
      timeLabel = elapsed.inMinutes < 60
          ? '${elapsed.inMinutes}m'
          : '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
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
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(timeLabel,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700)),
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
                  '${order.items.fold(0, (s, i) => s + i.activeQuantity)} item(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  _currency.format(order.totalAmount),
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
    if (_selectedTableId == null) return _buildIdleState();
    if (_isAddingItems) return _buildItemPickerPanel();
    final order = _tabOrders[_selectedTableId!];
    if (order == null) return _buildIdleState();
    final table = _tables.firstWhere((t) => t.id == _selectedTableId);
    return _buildOrderPanel(order, table);
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant_rounded,
              size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Select a table',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text(
            'Tap an available table to start a new order,\nor an occupied table to manage the running tab.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ─── Order view ───────────────────────────────────────

  Widget _buildOrderPanel(RestaurantOrder order, RestaurantTable table) {
    final subtotal = order.totalAmount;
    final tax = subtotal * 0.08;
    final total = subtotal + tax;
    final elapsed = DateTime.now().difference(order.createdAt);
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
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Order #${order.orderNumber}  ·  '
                    '${order.items.fold(0, (s, i) => s + i.activeQuantity)} item(s)',
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
                        builder: (_) =>
                            RestaurantInvoiceDialog(order: order, table: table),
                      )),
              const SizedBox(width: 8),
              _actionBtn(Icons.payment_rounded, 'Collect Payment', _kGreen,
                  onPressed:
                      _isProcessing ? null : () => _collectPayment(order, table)),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: order.items.length,
            itemBuilder: (_, i) => _buildOrderItemRow(order.items[i]),
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
              const SizedBox(height: 5),
              _totalRow('Tax (8%)', _currency.format(tax), muted: true),
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
    final isNewTab = !_tabOrders.containsKey(_selectedTableId!);
    final filteredItems = _selectedCategory == null
        ? _menuItems
        : _menuItems.where((m) => m.category == _selectedCategory).toList();
    final cartCount = _addCart.values.fold(0, (s, v) => s + v);
    final cartTotal = _addCart.entries.fold(0.0, (s, e) {
      if (e.value <= 0) return s;
      return s +
          _menuItems.firstWhere((m) => m.id == e.key).price * e.value;
    });

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
                    isNewTab
                        ? 'New Order — Table ${table.tableNumber}'
                        : 'Add to Tab — Table ${table.tableNumber}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    isNewTab
                        ? 'Select items to open the tab'
                        : 'Select items to add to the running tab',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Category chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
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
              }).toList(),
            ),
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
              childAspectRatio: 0.88,
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
                    cartCount > 0 && !_isProcessing ? _confirmAddItems : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(isNewTab ? 'Open Tab' : 'Add to Tab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
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
    final qty = _addCart[item.id] ?? 0;
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
                  const SizedBox(height: 8),
                  // Qty stepper — disabled when unavailable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stepBtn(
                        icon: Icons.remove_rounded,
                        enabled: !unavailable && qty > 0,
                        onTap: () =>
                            setState(() => _addCart[item.id] = qty - 1),
                      ),
                      Text('$qty',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: qty > 0 ? _kOrange : Colors.black26)),
                      _stepBtn(
                        icon: Icons.add_rounded,
                        enabled: !unavailable,
                        onTap: () =>
                            setState(() => _addCart[item.id] = qty + 1),
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
