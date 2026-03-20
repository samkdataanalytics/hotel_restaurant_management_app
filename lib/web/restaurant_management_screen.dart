import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/menu_item.dart';
import '../models/ingredient.dart';
import '../models/ingredient_price.dart';
import '../models/menu_item_cost_record.dart';
import '../models/restaurant_table.dart';
import '../models/restaurant_order.dart';
import '../models/inventory_item.dart';
import '../services/restaurant_service.dart';

// ─── Color palette for restaurant sections — sourced from AppTheme ───────────
class _RC {
  static const accent = AppTheme.restaurantAccent;
  static const accentLight = AppTheme.restaurantAccentBg;
  static const accentMid = AppTheme.restaurantAccentMid;
  static const available = AppTheme.statusGreen;
  static const availableLight = Color(0xFFDCFCE7);
  static const occupied = AppTheme.statusRed;
  static const occupiedLight = Color(0xFFFFE4E4);
  static const preparing = AppTheme.statusAmber;
  static const preparingLight = Color(0xFFFEF3C7);
  static const costBg = Color(0xFFF0FDF4);
  static const bg = AppTheme.pageBg;
}

class RestaurantManagementScreen extends StatefulWidget {
  const RestaurantManagementScreen({super.key});

  @override
  State<RestaurantManagementScreen> createState() => _RestaurantManagementScreenState();
}

class _RestaurantManagementScreenState extends State<RestaurantManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = RestaurantService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RC.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MenuTab(service: _service),
                _IngredientsTab(service: _service),
                _TablesTab(service: _service),
                _InventoryTab(service: _service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _RC.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: _RC.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Restaurant Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
              Text('Menu • Ingredients • Tables',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _RC.accent,
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: _RC.accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Menu Items'),
          Tab(icon: Icon(Icons.eco_rounded, size: 18), text: 'Ingredients & Costs'),
          Tab(icon: Icon(Icons.table_restaurant_rounded, size: 18), text: 'Tables & Occupancy'),
          Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Inventory'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — MENU ITEMS
// ═══════════════════════════════════════════════════════════════════════════

class _MenuTab extends StatefulWidget {
  final RestaurantService service;
  const _MenuTab({required this.service});
  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  List<MenuItem> _items = [];
  List<Ingredient> _ingredients = [];
  Map<String, double> _currentCosts = {};
  bool _loading = true;
  NumberFormat get _currency => NumberFormat.currency(
      symbol: Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.service.getMenuItems();
    final ingredients = await widget.service.getIngredients();
    final costs = <String, double>{};
    for (final item in items) {
      final c = await widget.service.getCurrentCostForItem(item.id);
      if (c != null) costs[item.id] = c;
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _ingredients = ingredients;
      _currentCosts = costs;
      _loading = false;
    });
  }

  void _openDialog([MenuItem? item]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _MenuItemDialog(
        service: widget.service,
        item: item,
        ingredients: _ingredients,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(MenuItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Menu Item'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.deleteMenuItem(item.id);
      _load();
    }
  }

  void _showCostHistory(MenuItem item) async {
    final records = await widget.service.getCostRecordsForItem(item.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _CostHistoryDialog(item: item, records: records),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Group items by category
    final categories = _items.map((e) => e.category).toSet().toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_items.length} Menu Items',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1E293B))),
              ElevatedButton.icon(
                onPressed: () => _openDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Menu Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _RC.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Per category sections
          ...categories.map((cat) {
            final catItems = _items.where((i) => i.category == cat).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _catHeader(cat),
                const SizedBox(height: 12),
                ...catItems.map((item) => _itemRow(item)),
                const SizedBox(height: 24),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _catHeader(String cat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _RC.accentLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _RC.accentMid),
      ),
      child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, color: _RC.accent, fontSize: 14)),
    );
  }

  Widget _itemRow(MenuItem item) {
    final cost = _currentCosts[item.id];
    final margin = cost != null && cost > 0 ? ((item.price - cost) / item.price * 100) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Emoji
          Text(item.imageUrl.isNotEmpty ? item.imageUrl : '🍽️',
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          // Name + description
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (item.description.isNotEmpty)
                  Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Ingredients count
          _pill('${item.ingredients.length} ingr.', Colors.grey.shade100, Colors.grey.shade600),
          const SizedBox(width: 12),
          // Selling price
          _labelValue('Price', _currency.format(item.price), AppTheme.adminPrimary),
          const SizedBox(width: 16),
          // Cost
          _labelValue('Cost', cost != null ? _currency.format(cost) : '—',
              cost != null ? const Color(0xFF16A34A) : Colors.grey.shade400),
          const SizedBox(width: 16),
          // Margin
          _labelValue('Margin', margin != null ? '${margin.toStringAsFixed(1)}%' : '—',
              margin != null ? (margin >= 50 ? const Color(0xFF16A34A) : _RC.preparing) : Colors.grey.shade400),
          const SizedBox(width: 16),
          // Available
          Switch(
            value: item.isAvailable,
            activeColor: _RC.available,
            onChanged: (val) async {
              await widget.service.saveMenuItem(item.copyWith(isAvailable: val));
              _load();
            },
          ),
          // Cost history
          IconButton(
            tooltip: 'Cost History',
            onPressed: () => _showCostHistory(item),
            icon: Icon(Icons.history_rounded, color: Colors.grey.shade400, size: 20),
          ),
          // Edit
          IconButton(
            tooltip: 'Edit',
            onPressed: () => _openDialog(item),
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          // Delete
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(item),
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade300, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _labelValue(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}

// ─── Menu Item Add/Edit Dialog ────────────────────────────────────────────────

class _MenuItemDialog extends StatefulWidget {
  final RestaurantService service;
  final MenuItem? item;
  final List<Ingredient> ingredients;
  const _MenuItemDialog({required this.service, this.item, required this.ingredients});
  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name, _description, _price, _emoji;
  late String _category;
  late bool _available;
  late List<MenuItemIngredient> _recipeIngredients;
  bool _saving = false;

  final _categories = ['Breakfast', 'Starters', 'Mains', 'Lunch', 'Dessert', 'Beverages', 'Other'];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(text: item?.price.toString() ?? '');
    _emoji = TextEditingController(text: item?.imageUrl ?? '');
    _category = item?.category ?? 'Mains';
    _available = item?.isAvailable ?? true;
    _recipeIngredients = List.from(item?.ingredients ?? []);
  }

  @override
  void dispose() {
    _name.dispose(); _description.dispose(); _price.dispose(); _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final item = MenuItem(
      id: widget.item?.id ?? _uuid.v4(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      category: _category,
      imageUrl: _emoji.text.trim(),
      isAvailable: _available,
      ingredients: _recipeIngredients,
    );
    await widget.service.saveMenuItem(item);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _addIngredient() {
    if (widget.ingredients.isEmpty) return;
    setState(() {
      _recipeIngredients.add(
        MenuItemIngredient(ingredientId: widget.ingredients.first.id, quantity: 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _RC.accentLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: _RC.accent, size: 22),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'Edit Menu Item' : 'Add Menu Item',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Name + Emoji
                      Row(children: [
                        Expanded(
                          flex: 3,
                          child: _field(_name, 'Item Name', validator: (v) => v!.isEmpty ? 'Required' : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _field(_emoji, 'Emoji / Icon')),
                      ]),
                      const SizedBox(height: 14),
                      // Row 2: Category + Price + Available
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _category,
                            decoration: _inputDeco('Category'),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(_price, 'Selling Price (\$)',
                              keyboardType: TextInputType.number,
                              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter valid price' : null),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            const Text('Available', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Switch(value: _available, activeColor: _RC.available,
                                onChanged: (v) => setState(() => _available = v)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _field(_description, 'Description', maxLines: 2),
                      const SizedBox(height: 20),
                      // ─── Ingredients Section ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ingredients / Recipe',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          TextButton.icon(
                            onPressed: widget.ingredients.isEmpty ? null : _addIngredient,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Ingredient'),
                            style: TextButton.styleFrom(foregroundColor: _RC.accent),
                          ),
                        ],
                      ),
                      if (widget.ingredients.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200)),
                          child: const Text(
                              'No ingredients found. Add ingredients in the "Ingredients & Costs" tab first.',
                              style: TextStyle(fontSize: 12, color: Colors.brown)),
                        )
                      else ...[
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Ingredient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                                    Expanded(child: Text('Qty Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54))),
                                    SizedBox(width: 40),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ..._recipeIngredients.asMap().entries.map((entry) {
                                final i = entry.key;
                                final ri = entry.value;
                                final ingr = widget.ingredients.firstWhere(
                                  (ing) => ing.id == ri.ingredientId,
                                  orElse: () => widget.ingredients.first,
                                );
                                return _ingredientRow(i, ri, ingr);
                              }),
                              if (_recipeIngredients.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No ingredients added yet.',
                                      style: TextStyle(color: Colors.black38, fontSize: 13)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(isEdit ? 'Save Changes' : 'Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _RC.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientRow(int i, MenuItemIngredient ri, Ingredient ingr) {
    final qtyCtrl = TextEditingController(text: ri.quantity.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButton<String>(
              value: ri.ingredientId,
              isExpanded: true,
              underline: const SizedBox(),
              items: widget.ingredients
                  .map((ing) => DropdownMenuItem(value: ing.id, child: Text('${ing.name} (${ing.unit})')))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _recipeIngredients[i] = ri.copyWith(ingredientId: val));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: ingr.unit,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
              onChanged: (v) {
                final q = double.tryParse(v) ?? 0;
                _recipeIngredients[i] = ri.copyWith(quantity: q);
              },
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _recipeIngredients.removeAt(i)),
            icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red.shade300, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDeco(label),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

// ─── Cost History Dialog ──────────────────────────────────────────────────────

class _CostHistoryDialog extends StatelessWidget {
  final MenuItem item;
  final List<MenuItemCostRecord> records;
  const _CostHistoryDialog({required this.item, required this.records});

  @override
  Widget build(BuildContext context) {
    final sym = Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';
    final currency = NumberFormat.currency(symbol: sym, decimalDigits: 2);
    final dateF = DateFormat('MMM dd, yyyy HH:mm');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _RC.costBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF16A34A)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Cost History — ${item.name}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No cost records yet.', style: TextStyle(color: Colors.black38)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final r = records[i];
                    final prev = i < records.length - 1 ? records[i + 1].cost : null;
                    final delta = prev != null ? r.cost - prev : null;
                    return ListTile(
                      dense: true,
                      title: Text(currency.format(r.cost),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      subtitle: Text(dateF.format(r.date),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      trailing: delta != null
                          ? _deltaBadge(sym, delta)
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: const Text('First record', style: TextStyle(fontSize: 11, color: Colors.black45)),
                            ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaBadge(String sym, double delta) {
    final isUp = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isUp ? _RC.occupiedLight : _RC.availableLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: isUp ? _RC.occupied : _RC.available),
          const SizedBox(width: 2),
          Text('${sym}${delta.abs().toStringAsFixed(2)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isUp ? _RC.occupied : _RC.available)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2 — INGREDIENTS & COSTS
// ═══════════════════════════════════════════════════════════════════════════

class _IngredientsTab extends StatefulWidget {
  final RestaurantService service;
  const _IngredientsTab({required this.service});
  @override
  State<_IngredientsTab> createState() => _IngredientsTabState();
}

class _IngredientsTabState extends State<_IngredientsTab> {
  List<Ingredient> _ingredients = [];
  Map<String, double?> _currentPrices = {};
  Ingredient? _selected;
  List<IngredientPrice> _selectedHistory = [];
  bool _loading = true;
  NumberFormat get _currency => NumberFormat.currency(
      symbol: Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 4);
  final _dateF = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ingredients = await widget.service.getIngredients();
    final prices = <String, double?>{};
    for (final ing in ingredients) {
      prices[ing.id] = await widget.service.getCurrentPriceForIngredient(ing.id);
    }
    if (!mounted) return;
    setState(() {
      _ingredients = ingredients;
      _currentPrices = prices;
      _loading = false;
      if (_selected != null) {
        _selected = ingredients.firstWhere((i) => i.id == _selected!.id, orElse: () => ingredients.isNotEmpty ? ingredients.first : _selected!);
      }
    });
    if (_selected != null) _loadHistory(_selected!);
  }

  Future<void> _loadHistory(Ingredient ing) async {
    final history = await widget.service.getPricesForIngredient(ing.id);
    if (!mounted) return;
    setState(() => _selectedHistory = history);
  }

  void _selectIngredient(Ingredient ing) {
    setState(() {
      _selected = ing;
      _selectedHistory = [];
    });
    _loadHistory(ing);
  }

  void _addIngredientDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _IngredientDialog(service: widget.service),
    );
    if (result == true) _load();
  }

  void _updatePriceDialog(Ingredient ing) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _UpdatePriceDialog(service: widget.service, ingredient: ing),
    );
    if (result == true) _load();
  }

  Future<void> _deleteIngredient(Ingredient ing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Ingredient'),
        content: Text('Delete "${ing.name}"? Menu items using it will lose this ingredient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.deleteIngredient(ing.id);
      if (_selected?.id == ing.id) setState(() { _selected = null; _selectedHistory = []; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Ingredient list
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_ingredients.length} Ingredients',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ElevatedButton.icon(
                      onPressed: _addIngredientDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RC.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: _ingredients.length,
                    itemBuilder: (_, i) {
                      final ing = _ingredients[i];
                      final price = _currentPrices[ing.id];
                      final isSelected = _selected?.id == ing.id;
                      return GestureDetector(
                        onTap: () => _selectIngredient(ing),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? _RC.accentLight : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _RC.accent : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? _RC.accentMid : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.eco_rounded,
                                    size: 18, color: isSelected ? _RC.accent : Colors.grey.shade400),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ing.name, style: TextStyle(fontWeight: FontWeight.w600,
                                        fontSize: 14, color: isSelected ? _RC.accent : const Color(0xFF1E293B))),
                                    Text('per ${ing.unit}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(price != null ? _currency.format(price) : '—',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                          color: price != null ? const Color(0xFF16A34A) : Colors.grey.shade400)),
                                  Text('current', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right: Price history panel
          Expanded(
            child: _selected == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Select an ingredient to view price history',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                      ],
                    ),
                  )
                : _buildHistoryPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    final ing = _selected!;
    final price = _currentPrices[ing.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: _RC.accentLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.eco_rounded, color: _RC.accent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    Text('Measured per ${ing.unit}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price != null ? _currency.format(price) : 'No price set',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 22,
                          color: price != null ? const Color(0xFF16A34A) : Colors.grey.shade400)),
                  Text('current price / ${ing.unit}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _updatePriceDialog(ing),
                    icon: const Icon(Icons.update_rounded, size: 16),
                    label: const Text('Update Price'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _RC.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _deleteIngredient(ing),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      textStyle: const TextStyle(fontSize: 12),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Price history table
        const Text('Price History',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _selectedHistory.isEmpty
                ? const Center(child: Text('No price records yet.', style: TextStyle(color: Colors.black38)))
                : Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54))),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Price / Unit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54))),
                            const SizedBox(width: 12),
                            const Expanded(child: Text('Change', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54))),
                            const Expanded(child: Text('Note', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                          itemCount: _selectedHistory.length,
                          itemBuilder: (_, i) {
                            final record = _selectedHistory[i];
                            final prev = i < _selectedHistory.length - 1 ? _selectedHistory[i + 1].pricePerUnit : null;
                            final delta = prev != null ? record.pricePerUnit - prev : null;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(_dateF.format(record.date),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(_currency.format(record.pricePerUnit),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: _priceChangeBadge(delta)),
                                  Expanded(
                                    child: Text(record.note ?? '—',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _priceChangeBadge(double? delta) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
        child: const Text('Initial', style: TextStyle(fontSize: 11, color: Colors.black38)),
      );
    }
    final isUp = delta > 0;
    final isFlat = delta == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFlat ? Colors.grey.shade100 : (isUp ? _RC.occupiedLight : _RC.availableLight),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFlat) Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 11,
            color: isUp ? _RC.occupied : _RC.available,
          ),
          Text(
            isFlat ? 'No change' : '${isUp ? '+' : ''}\$${delta.abs().toStringAsFixed(4)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isFlat ? Colors.grey.shade500 : (isUp ? _RC.occupied : _RC.available)),
          ),
        ],
      ),
    );
  }
}

// ─── Add Ingredient Dialog ────────────────────────────────────────────────────

class _IngredientDialog extends StatefulWidget {
  final RestaurantService service;
  final Ingredient? ingredient;
  const _IngredientDialog({required this.service, this.ingredient});
  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late String _unit;
  bool _saving = false;

  final _units = ['piece', 'kg', 'gram', 'litre', 'ml', 'slice', 'cup', 'tbsp', 'tsp'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.ingredient?.name ?? '');
    _unit = widget.ingredient?.unit ?? 'piece';
  }

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ing = Ingredient(
        id: widget.ingredient?.id ?? _uuid.v4(),
        name: _name.text.trim(),
        unit: _unit,
      );
      await widget.service.saveIngredient(ing);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ingredient: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, color: _RC.accent),
                    const SizedBox(width: 10),
                    Text(widget.ingredient != null ? 'Edit Ingredient' : 'Add Ingredient',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Ingredient Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: InputDecoration(
                    labelText: 'Unit of Measurement',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => _unit = v!),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RC.accent, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(widget.ingredient != null ? 'Save' : 'Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Update Price Dialog ──────────────────────────────────────────────────────

class _UpdatePriceDialog extends StatefulWidget {
  final RestaurantService service;
  final Ingredient ingredient;
  const _UpdatePriceDialog({required this.service, required this.ingredient});
  @override
  State<_UpdatePriceDialog> createState() => _UpdatePriceDialogState();
}

class _UpdatePriceDialogState extends State<_UpdatePriceDialog> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _priceCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final record = IngredientPrice(
      id: _uuid.v4(),
      ingredientId: widget.ingredient.id,
      pricePerUnit: double.parse(_priceCtrl.text),
      date: DateTime.now(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    await widget.service.addIngredientPrice(record);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.price_change_rounded, color: _RC.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Update Market Price — ${widget.ingredient.name}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price per ${widget.ingredient.unit} (\$)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid price' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. Market price increase',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _RC.preparingLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: _RC.preparing),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Saving this price will recalculate costs for all menu items using this ingredient.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Save Price'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RC.accent, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3 — TABLES & OCCUPANCY
// ═══════════════════════════════════════════════════════════════════════════

class _TablesTab extends StatefulWidget {
  final RestaurantService service;
  const _TablesTab({required this.service});
  @override
  State<_TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<_TablesTab> {
  List<RestaurantTable> _tables = [];
  Map<String, List<RestaurantOrder>> _activeOrders = {};
  bool _loading = true;
  NumberFormat get _currency => NumberFormat.currency(
      symbol: Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$',
      decimalDigits: 2);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh so floor manager sees kitchen status updates in real-time
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final tables = await widget.service.getTables();
    final orders = <String, List<RestaurantOrder>>{};
    for (final t in tables) {
      final list = await widget.service.getOpenOrdersForTable(t.id);
      if (list.isNotEmpty) {
        orders[t.id] = list;
      }
    }
    if (!mounted) return;
    setState(() {
      _tables = tables;
      _activeOrders = orders;
      _loading = false;
    });
  }

  void _addTableDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AddTableDialog(service: widget.service, existingCount: _tables.length),
    );
    if (result == true) _load();
  }

  Future<void> _deleteTable(RestaurantTable table) async {
    if (_activeOrders[table.id] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete a table with an active order.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Table'),
        content: Text('Delete Table ${table.tableNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.deleteTable(table.id);
      _load();
    }
  }

  void _showOrderDetail(RestaurantTable table, List<RestaurantOrder> orders) {
    showDialog(
      context: context,
      builder: (_) => _TableOrderDialog(table: table, orders: orders, currency: _currency),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final occupied = _tables.where((t) => _activeOrders[t.id] != null).length;
    final available = _tables.length - occupied;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Row(
            children: [
              _statChip(Icons.table_restaurant_rounded, '${_tables.length} Total', Colors.grey.shade600, Colors.grey.shade100),
              const SizedBox(width: 12),
              _statChip(Icons.check_circle_outline_rounded, '$available Available', _RC.available, _RC.availableLight),
              const SizedBox(width: 12),
              _statChip(Icons.people_rounded, '$occupied Occupied', _RC.occupied, _RC.occupiedLight),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addTableDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Table'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _RC.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Table grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _tables.length,
            itemBuilder: (_, i) => _tableCard(_tables[i]),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(RestaurantTable table) {
    final orders = _activeOrders[table.id];
    final isOccupied = orders != null && orders.isNotEmpty;
    final latestOrder = isOccupied ? orders.last : null;

    final bgColor = isOccupied ? _RC.occupiedLight : _RC.availableLight;
    final borderColor = isOccupied ? _RC.occupied.withOpacity(0.4) : _RC.available.withOpacity(0.4);
    final iconColor = isOccupied ? _RC.occupied : _RC.available;
    final statusLabel = isOccupied ? _orderStatusLabel(latestOrder!.status) : 'Available';
    final statusColor = isOccupied ? _orderStatusColor(latestOrder!.status) : _RC.available;

    return GestureDetector(
      onTap: isOccupied ? () => _showOrderDetail(table, orders) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.table_restaurant_rounded, color: iconColor, size: 22),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteTable(table),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Table ${table.tableNumber}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: isOccupied ? _RC.occupied : _RC.available)),
            Text('${table.capacity} seats',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const Spacer(),
            if (isOccupied && latestOrder != null) ...[
              const Divider(color: Colors.black12),
              // Kitchen status badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kitchenStatusColor(latestOrder).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_kitchenStatusIcon(latestOrder),
                            size: 11, color: _kitchenStatusColor(latestOrder)),
                        const SizedBox(width: 4),
                        Text(_kitchenStatusLabel(latestOrder),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kitchenStatusColor(latestOrder))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('${orders.fold(0, (s, o) => s + o.items.where((i) => !i.isFullyRefunded).fold(0, (s2, i) => s2 + i.activeQuantity))} items',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF7C2D12))),
                ],
              ),
              const SizedBox(height: 6),
              Text(_currency.format(orders.fold(0.0, (s, o) => s + o.totalAmount)),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _RC.occupied)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 12, color: Colors.black38),
                  const SizedBox(width: 4),
                  Text('Tap for details',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ] else ...[
              const Divider(color: Colors.black12),
              Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: _RC.available),
                  const SizedBox(width: 4),
                  Text('Ready for guests',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  String _orderStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return 'Pending';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.ready: return 'Ready';
      case OrderStatus.served: return 'Served';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }

  Color _orderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return _RC.preparing;
      case OrderStatus.preparing: return AppTheme.adminPrimary;
      case OrderStatus.ready: return _RC.available;
      case OrderStatus.served: return Colors.grey;
      case OrderStatus.cancelled: return _RC.occupied;
    }
  }

  // Kitchen-aware status helpers (served+unpaid → Payment Due)
  String _kitchenStatusLabel(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return 'Payment Due';
    switch (order.status) {
      case OrderStatus.pending:    return 'Pending';
      case OrderStatus.preparing:  return 'Preparing';
      case OrderStatus.ready:      return 'Ready to Serve';
      case OrderStatus.served:     return 'Served';
      case OrderStatus.cancelled:  return 'Cancelled';
    }
  }

  Color _kitchenStatusColor(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return Colors.purple;
    switch (order.status) {
      case OrderStatus.pending:    return _RC.preparing;
      case OrderStatus.preparing:  return AppTheme.adminPrimary;
      case OrderStatus.ready:      return _RC.available;
      case OrderStatus.served:     return Colors.grey;
      case OrderStatus.cancelled:  return _RC.occupied;
    }
  }

  IconData _kitchenStatusIcon(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return Icons.payments_rounded;
    switch (order.status) {
      case OrderStatus.pending:    return Icons.hourglass_top_rounded;
      case OrderStatus.preparing:  return Icons.outdoor_grill_rounded;
      case OrderStatus.ready:      return Icons.check_circle_rounded;
      case OrderStatus.served:     return Icons.done_all_rounded;
      case OrderStatus.cancelled:  return Icons.cancel_rounded;
    }
  }
}

// ─── Add Table Dialog ─────────────────────────────────────────────────────────

class _AddTableDialog extends StatefulWidget {
  final RestaurantService service;
  final int existingCount;
  const _AddTableDialog({required this.service, required this.existingCount});
  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tableNumber;
  int _capacity = 2;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tableNumber = TextEditingController(text: '${widget.existingCount + 1}');
  }

  @override
  void dispose() { _tableNumber.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final table = RestaurantTable(
        id: _uuid.v4(),
        tableNumber: _tableNumber.text.trim(),
        capacity: _capacity,
      );
      await widget.service.saveTable(table);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save table: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_rounded, color: _RC.accent),
                    const SizedBox(width: 10),
                    const Text('Add Table', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _tableNumber,
                  decoration: InputDecoration(
                    labelText: 'Table Number / Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Seating Capacity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [2, 4, 6, 8, 10].map((cap) {
                    final sel = _capacity == cap;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _capacity = cap),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: sel ? _RC.accent : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('$cap', style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14,
                                color: sel ? Colors.white : Colors.black54)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _RC.accent, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Add Table'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Table Order Detail Dialog ────────────────────────────────────────────────

class _TableOrderDialog extends StatelessWidget {
  final RestaurantTable table;
  final List<RestaurantOrder> orders;
  final NumberFormat currency;
  const _TableOrderDialog({required this.table, required this.orders, required this.currency});

  String _statusLabel(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return 'Payment Due';
    switch (order.status) {
      case OrderStatus.pending:   return 'Pending';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.ready:     return 'Ready to Serve';
      case OrderStatus.served:    return 'Served';
      case OrderStatus.cancelled: return 'Cancelled';
    }
  }

  Color _statusColor(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return Colors.purple;
    switch (order.status) {
      case OrderStatus.pending:   return _RC.preparing;
      case OrderStatus.preparing: return AppTheme.adminPrimary;
      case OrderStatus.ready:     return _RC.available;
      case OrderStatus.served:    return Colors.grey;
      case OrderStatus.cancelled: return _RC.occupied;
    }
  }

  IconData _statusIcon(RestaurantOrder order) {
    if (order.status == OrderStatus.served &&
        order.paymentStatus == PaymentStatus.unpaid) return Icons.payments_rounded;
    switch (order.status) {
      case OrderStatus.pending:   return Icons.hourglass_top_rounded;
      case OrderStatus.preparing: return Icons.outdoor_grill_rounded;
      case OrderStatus.ready:     return Icons.check_circle_rounded;
      case OrderStatus.served:    return Icons.done_all_rounded;
      case OrderStatus.cancelled: return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeF = DateFormat('HH:mm');
    final latestOrder = orders.last;
    final statusColor = _statusColor(latestOrder);

    // Flatten all items across all orders for this table
    final allItemsWidget = <Widget>[];
    for (var idx = 0; idx < orders.length; idx++) {
      final order = orders[idx];
      if (orders.length > 1) {
        allItemsWidget.add(Padding(
          padding: EdgeInsets.only(bottom: 8, top: idx == 0 ? 0 : 16),
          child: Row(
            children: [
              Text(order.parentOrderId != null ? 'Add-On Ticket #${order.orderNumber}' : 'Ticket #${order.orderNumber}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.indigo.shade600)),
              const Spacer(),
              Text(_statusLabel(order), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ));
      }
      for (final item in order.items) {
        allItemsWidget.add(Row(
          children: [
            Text(item.menuItem.imageUrl.isNotEmpty ? item.menuItem.imageUrl : '🍽️',
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.menuItem.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(currency.format(item.menuItem.price),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _RC.accentLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('x${item.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _RC.accent)),
            ),
            const SizedBox(width: 12),
            Text(currency.format(item.subtotal),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ));
        allItemsWidget.add(Divider(color: Colors.grey.shade100));
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _RC.occupiedLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: _RC.occupied.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.table_restaurant_rounded, color: _RC.occupied, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Table ${table.tableNumber} — Active Order',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('${orders.map((o) => o.orderNumber).join(" + ")} • Placed at ${timeF.format(orders.first.createdAt)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            // Kitchen status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: statusColor.withOpacity(0.08),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(latestOrder), size: 18, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kitchen Status',
                          style: TextStyle(fontSize: 11, color: Colors.black45)),
                      Text(_statusLabel(latestOrder),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ],
                  ),
                  if (orders.length > 1) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${orders.length} TICKETS', 
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                    ),
                  ]
                ],
              ),
            ),
            // Items
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: allItemsWidget,
              ),
            ),
            // Total
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${orders.fold(0, (s, o) => s + o.items.fold(0, (s2, i) => s2 + i.quantity))} items',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      Text('Payment: ${_paymentLabel(latestOrder.paymentStatus)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: Colors.black45)),
                      Text(currency.format(orders.fold(0.0, (s, o) => s + o.totalAmount)),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: _RC.occupied)),
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

  String _paymentLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid: return 'Unpaid';
      case PaymentStatus.paid: return 'Paid';
      case PaymentStatus.chargedToRoom: return 'Charged to Room';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 4 — INVENTORY
// ═══════════════════════════════════════════════════════════════════════════

class _InventoryTab extends StatefulWidget {
  final RestaurantService service;
  const _InventoryTab({required this.service});
  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  List<Ingredient> _ingredients = [];
  List<InventoryItem> _inventory = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ingredients = await widget.service.getIngredients();
    final inventory   = await widget.service.getInventory();
    if (!mounted) return;
    setState(() { _ingredients = ingredients; _inventory = inventory; _loading = false; });
  }

  InventoryItem? _invFor(String id) {
    try { return _inventory.firstWhere((i) => i.ingredientId == id); }
    catch (_) { return null; }
  }

  void _adjustDialog(Ingredient ing) async {
    final inv = _invFor(ing.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _StockAdjustDialog(
        service: widget.service, ingredient: ing,
        current: inv?.currentStock ?? 0, minLevel: inv?.minStockLevel ?? 0,
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final lowCount = _ingredients.where((i) { final v = _invFor(i.id); return v != null && v.isLow; }).length;
    final outCount = _ingredients.where((i) { final v = _invFor(i.id); return v != null && v.isOut; }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, children: [
            _chip(Icons.inventory_2_rounded,          '${_ingredients.length} Total',    Colors.grey.shade600, Colors.grey.shade100),
            _chip(Icons.check_circle_outline_rounded, '${_ingredients.length - lowCount - outCount} OK', _RC.available,  _RC.availableLight),
            _chip(Icons.warning_amber_rounded,        '$lowCount Low Stock',              _RC.preparing,  _RC.preparingLight),
            _chip(Icons.remove_circle_outline_rounded,'$outCount Out of Stock',           _RC.occupied,   _RC.occupiedLight),
          ]),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(children: [
                  Expanded(flex: 3, child: _TH('Ingredient')),
                  Expanded(child: _TH('Unit')),
                  Expanded(child: _TH('In Stock', center: true)),
                  Expanded(child: _TH('Min Level', center: true)),
                  Expanded(child: _TH('Status', center: true)),
                  SizedBox(width: 90, child: _TH('Action', center: true)),
                ]),
              ),
              const Divider(height: 1),
              ..._ingredients.asMap().entries.map((e) =>
                  _buildRow(e.value, _invFor(e.value.id), e.key == _ingredients.length - 1)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Ingredient ing, InventoryItem? inv, bool last) {
    final stock    = inv?.currentStock ?? 0;
    final minLevel = inv?.minStockLevel ?? 0;
    final isOut    = stock <= 0;
    final isLow    = !isOut && (inv?.isLow ?? false);
    Color bg = Colors.white;
    if (isOut)      bg = _RC.occupiedLight.withOpacity(0.4);
    else if (isLow) bg = _RC.preparingLight.withOpacity(0.35);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        border: last ? null : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isOut ? _RC.occupiedLight : isLow ? _RC.preparingLight : _RC.availableLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.eco_rounded, size: 16,
                color: isOut ? _RC.occupied : isLow ? _RC.preparing : _RC.available),
          ),
          const SizedBox(width: 12),
          Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ])),
        Expanded(child: Text(ing.unit, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
        Expanded(child: Center(child: Text(
          _fmt(stock),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
              color: isOut ? _RC.occupied : isLow ? _RC.preparing : const Color(0xFF1E293B)),
        ))),
        Expanded(child: Center(child: Text(_fmt(minLevel),
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)))),
        Expanded(child: Center(child: _statusBadge(inv))),
        SizedBox(width: 90, child: Center(child: TextButton.icon(
          onPressed: () => _adjustDialog(ing),
          icon: const Icon(Icons.tune_rounded, size: 14),
          label: const Text('Adjust', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: _RC.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
        ))),
      ]),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  Widget _statusBadge(InventoryItem? inv) {
    if (inv == null || inv.isOut) return _pill('Out',  _RC.occupied,  _RC.occupiedLight);
    if (inv.isLow)                return _pill('Low',  _RC.preparing, _RC.preparingLight);
    return                               _pill('OK',   _RC.available, _RC.availableLight);
  }

  Widget _pill(String label, Color c, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _chip(IconData icon, String label, Color c, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c)),
    ]),
  );
}

// ─── _TH — reusable table column header ──────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  final bool center;
  const _TH(this.text, {this.center = false});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45));
}

// ─── Stock Adjust Dialog ──────────────────────────────────────────────────────

class _StockAdjustDialog extends StatefulWidget {
  final RestaurantService service;
  final Ingredient ingredient;
  final double current;
  final double minLevel;
  const _StockAdjustDialog({
    required this.service, required this.ingredient,
    required this.current, required this.minLevel,
  });
  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  late TextEditingController _amtCtrl;
  late TextEditingController _minCtrl;
  bool _isAdding = true;
  bool _saving   = false;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController();
    _minCtrl = TextEditingController(text: widget.minLevel.toString());
  }

  @override
  void dispose() { _amtCtrl.dispose(); _minCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = double.tryParse(_amtCtrl.text);
    final min    = double.tryParse(_minCtrl.text) ?? widget.minLevel;
    if (amount == null || amount < 0) return;
    setState(() => _saving = true);
    await widget.service.adjustStock(widget.ingredient.id, _isAdding ? amount : -amount);
    final inv = await widget.service.getInventoryForIngredient(widget.ingredient.id);
    if (inv != null) await widget.service.updateInventoryItem(inv.copyWith(minStockLevel: min));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.inventory_2_rounded, color: _RC.accent),
              const SizedBox(width: 10),
              Expanded(child: Text('Adjust Stock — ${widget.ingredient.name}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: _RC.accentLight, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Current Stock', style: TextStyle(fontSize: 13, color: Colors.black54)),
                Text('${widget.current.toStringAsFixed(1)} ${widget.ingredient.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _RC.accent)),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _toggleBtn('Add Stock',    true,  _RC.available)),
              const SizedBox(width: 8),
              Expanded(child: _toggleBtn('Remove Stock', false, _RC.occupied)),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${_isAdding ? 'Add' : 'Remove'} Amount (${widget.ingredient.unit})',
                prefixIcon: Icon(_isAdding ? Icons.add_rounded : Icons.remove_rounded,
                    color: _isAdding ? _RC.available : _RC.occupied),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Min Alert Level (${widget.ingredient.unit})',
                prefixIcon: const Icon(Icons.warning_amber_rounded, color: _RC.preparing),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _RC.accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool add, Color c) {
    final sel = _isAdding == add;
    return GestureDetector(
      onTap: () => setState(() => _isAdding = add),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: sel ? Border.all(color: c.withOpacity(0.4)) : null,
        ),
        child: Center(child: Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                color: sel ? c : Colors.grey.shade500))),
      ),
    );
  }
}
