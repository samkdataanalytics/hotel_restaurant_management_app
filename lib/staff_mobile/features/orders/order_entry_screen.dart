import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/menu_item.dart';
import '../../../domain/entities/restaurant_order.dart';
import '../../../providers/service_providers.dart';
import '../../data/connectivity.dart';
import '../../data/outbox.dart';
import '../../data/restaurant_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';
import '../shell/staff_tabs.dart';
import 'cart_sheet.dart';
import 'modifier_sheet.dart';
import 'order_cart.dart';
import '../../data/money.dart';

const _uuid = Uuid();

/// Everything order entry needs for one table, loaded in parallel.
typedef _OrderContext = ({
  TableFloorEntry entry,
  Map<String, List<MenuItem>> menu,
  bool menuIsStale,
});

/// Menu only, for an order with no table behind it.
final _menuOnlyProvider =
    FutureProvider.autoDispose<Map<String, List<MenuItem>>>((ref) async {
  final cached =
      await ref.watch(restaurantRepositoryProvider).loadMenuByCategory();
  return cached.value;
});

final _orderContextProvider = FutureProvider.autoDispose
    .family<_OrderContext, String>((ref, tableId) async {
  final repo = ref.watch(restaurantRepositoryProvider);
  // The menu and the table's open orders are independent reads — serialising
  // them would double the wait before a waiter can start tapping.
  final results = await (repo.loadTable(tableId), repo.loadMenuByCategory()).wait;
  return (entry: results.$1, menu: results.$2.value, menuIsStale: results.$2.isStale);
});

/// Order entry: browse the menu, build a round, fire it to the kitchen.
///
/// Not a port of `lib/web/pos_screen.dart` (3,014 lines, built for a mouse and
/// a wide screen). This is laid out for one hand while standing: a sticky
/// category rail, a large-target menu list, and a cart that stays one tap away
/// at the bottom of the screen.
class OrderEntryScreen extends ConsumerStatefulWidget {
  /// Null for an order with no table — a delivery taken over the phone.
  final String? tableId;

  /// Dine-in for a table, delivery for a platform order.
  final OrderType type;

  const OrderEntryScreen({
    super.key,
    this.tableId,
    this.type = OrderType.dineIn,
  }) : assert(tableId != null || type == OrderType.delivery,
            'Only a delivery order may have no table.');

  bool get isDelivery => type == OrderType.delivery;

  @override
  ConsumerState<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends ConsumerState<OrderEntryScreen> {
  OrderCart _cart = const OrderCart();
  String _search = '';

  /// Delivery only. Defaults to the first platform rather than empty, because
  /// every delivery order has one and an unset dropdown is just a step.
  String _platform = _deliveryPlatforms.first;
  final _deliveryRef = TextEditingController();

  /// The same three the web POS offers, so reporting groups consistently.
  static const _deliveryPlatforms = ['UberEats', 'PickMe', 'Other'];

  String? _category;
  bool _sending = false;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _deliveryRef.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(staffSessionProvider).valueOrNull;

    // Permission is re-checked here, not just on the floor: this screen is
    // reachable by deep link, and a privilege can change mid-session.
    if (session != null && !canTakeOrders(session)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'You have view-only access to the POS section, so you cannot '
              'take orders.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // A delivery order has no table to load, so it reads the menu alone.
    return widget.isDelivery ? _deliveryScaffold() : _tableScaffold();
  }

  Widget _tableScaffold() {
    final contextAsync = ref.watch(_orderContextProvider(widget.tableId!));

    return contextAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _errorScaffold(
        'Could not open this table.',
        e,
        () => ref.invalidate(_orderContextProvider(widget.tableId!)),
      ),
      data: (ctx) {
        final entry = ctx.entry;
        final isSecondRound = entry.activeOrder != null;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Table ${entry.table.tableNumber}'),
                Text(
                  isSecondRound
                      ? 'Adding to order #${entry.activeOrder!.orderNumber}'
                      : 'New order',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              if (isSecondRound) _RunningTab(entry: entry),
              ..._menuBody(ctx.menu),
            ],
          ),
          bottomNavigationBar: _cart.isEmpty
              ? null
              : _CartBar(
                  cart: _cart,
                  sending: _sending,
                  onReview: _reviewCart,
                  onSend: () => _send(entry),
                  isSecondRound: isSecondRound,
                ),
        );
      },
    );
  }

  Widget _deliveryScaffold() {
    final menuAsync = ref.watch(_menuOnlyProvider);
    final scheme = Theme.of(context).colorScheme;

    return menuAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _errorScaffold(
        'Could not load the menu.',
        e,
        () => ref.invalidate(_menuOnlyProvider),
      ),
      data: (menu) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Delivery order'),
              Text(
                _platform,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _platform,
                      isDense: true,
                      decoration: const InputDecoration(
                        labelText: 'Platform',
                        prefixIcon: Icon(Icons.delivery_dining_outlined),
                      ),
                      items: [
                        for (final p in _deliveryPlatforms)
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: (v) =>
                          setState(() => _platform = v ?? _platform),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _deliveryRef,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Their ref',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._menuBody(menu),
          ],
        ),
        bottomNavigationBar: _cart.isEmpty
            ? null
            : _CartBar(
                cart: _cart,
                sending: _sending,
                onReview: _reviewCart,
                onSend: () => _send(null),
                isSecondRound: false,
              ),
      ),
    );
  }

  Widget _errorScaffold(String message, Object error, VoidCallback onRetry) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$message\n\n$error', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Search, categories and the menu list — identical either way, so the two
  /// scaffolds share it rather than each growing their own copy.
  List<Widget> _menuBody(Map<String, List<MenuItem>> menu) {
    final categories = menu.keys.toList();
    final activeCategory =
        _category != null && menu.containsKey(_category) ? _category : null;
    final visible = _visibleItems(menu, activeCategory);

    return [
      _SearchBar(
        controller: _searchController,
        onChanged: (v) => setState(() => _search = v),
      ),
      if (categories.length > 1 && _search.isEmpty)
        _CategoryRail(
          categories: categories,
          selected: activeCategory,
          onSelected: (c) => setState(() => _category = c),
        ),
      Expanded(
        child: visible.isEmpty
            ? const _NoMatches()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _MenuRow(
                  item: visible[i],
                  inCart: _quantityOf(visible[i].id),
                  onTap: () => _addItem(visible[i]),
                  onLongPress: () => _addItem(visible[i], forceSheet: true),
                ),
              ),
      ),
    ];
  }

  List<MenuItem> _visibleItems(
    Map<String, List<MenuItem>> menu,
    String? category,
  ) {
    // A search spans every category — a waiter looking for "fries" should not
    // have to know which section it lives in.
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      return [
        for (final items in menu.values)
          ...items.where((i) =>
              i.name.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q)),
      ];
    }
    if (category != null) return menu[category] ?? const [];
    return [for (final items in menu.values) ...items];
  }

  int _quantityOf(String menuItemId) => _cart.items
      .where((i) => i.menuItem.id == menuItemId)
      .fold(0, (sum, i) => sum + i.quantity);

  Future<void> _addItem(MenuItem item, {bool forceSheet = false}) async {
    // A plain item goes straight in — confirming a Coke is how a POS ends up
    // slower than a notepad. The sheet appears only when there is a real
    // choice to make, or on a long-press when a note is wanted.
    if (item.modifiers.isEmpty && !forceSheet) {
      setState(() => _cart = _cart.add(item));
      return;
    }

    final selection = await showModifierSheet(context, item: item);
    if (selection == null || !mounted) return;

    setState(() {
      _cart = _cart.add(
        item,
        quantity: selection.quantity,
        modifiers: selection.modifiers,
        notes: selection.notes,
      );
    });
  }

  Future<void> _reviewCart() async {
    final updated = await showCartSheet(context, cart: _cart);
    if (updated == null || !mounted) return;
    setState(() => _cart = updated);
  }

  Future<void> _send(TableFloorEntry? entry) async {
    if (_cart.isEmpty || _sending) return;

    setState(() => _sending = true);
    final service = ref.read(restaurantServiceProvider);
    final isOnline = ref.read(isOnlineProvider);
    final propertyId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;
    final items = _cart.items;
    final label = entry == null ? _platform : 'table ${entry.table.tableNumber}';

    var queued = false;

    try {
      if (entry == null) {
        // Delivery: no table, so it goes through saveOrder with the platform
        // and their reference attached, which is what makes it show up in the
        // same reporting as everything else.
        final ts = DateTime.now();
        await service.saveOrder(RestaurantOrder(
          id: _uuid.v4(),
          orderNumber: ts.millisecondsSinceEpoch.toString().substring(7),
          type: OrderType.delivery,
          status: OrderStatus.pending,
          paymentStatus: PaymentStatus.unpaid,
          createdAt: ts,
          items: items,
          deliveryPlatform: _platform,
          deliveryOrderRef: _deliveryRef.text.trim().isEmpty
              ? null
              : _deliveryRef.text.trim(),
        ));
      } else if (entry.activeOrder != null) {
        // Second round: append to the open order rather than creating a new
        // one, so the table settles as a single bill.
        await service.addItemsToOrder(entry.activeOrder!.id, items);
      } else {
        await service.createTableOrder(
          tableId: entry.table.id,
          items: items,
          type: OrderType.dineIn,
        );
      }
    } catch (e) {
      // The write failed. If the device is offline this is expected, and the
      // round is queued rather than lost — a waiter who has already told the
      // kitchen "it's in" must not discover later that it was not.
      //
      // Delivery orders are NOT queued: their platform reference is the link
      // back to an order the platform already accepted, and replaying one
      // blind minutes later risks duplicating a delivery that was re-entered
      // by hand in the meantime.
      if (!isOnline && propertyId != null && entry != null) {
        try {
          if (entry.activeOrder != null) {
            await ref.read(outboxProvider.notifier).queueAddItems(
                  propertyId: propertyId,
                  orderId: entry.activeOrder!.id,
                  items: items,
                );
          } else {
            await ref.read(outboxProvider.notifier).queueCreateOrder(
                  propertyId: propertyId,
                  tableId: entry.table.id,
                  items: items,
                );
          }
          queued = true;
        } catch (queueError) {
          // Queueing itself failed — the storage is unavailable. Say so
          // plainly rather than implying the order is safe.
          if (!mounted) return;
          setState(() => _sending = false);
          showWriteFailure(
            context,
            error: queueError,
            isOnline: isOnline,
            action: 'Saving the order for later',
          );
          return;
        }
      } else {
        if (!mounted) return;
        setState(() => _sending = false);
        showWriteFailure(
          context,
          error: e,
          isOnline: isOnline,
          action: 'Sending the order',
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _cart = _cart.clear();
      _sending = false;
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Saved for $label — it will send when you are back online'
                : 'Sent to the kitchen — $label',
          ),
          duration: Duration(seconds: queued ? 5 : 3),
        ),
      );
    Navigator.of(context).pop();
  }
}

/// Summary of what the table already owes, shown when adding a second round.
class _RunningTab extends ConsumerWidget {
  final TableFloorEntry entry;
  const _RunningTab({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Already on this table: ${entry.openItemCount} item'
              '${entry.openItemCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          Text(
            money.format(entry.openTotal),
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search the menu',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(c),
              selected: selected == c,
              onSelected: (_) => onSelected(c),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends ConsumerWidget {
  final MenuItem item;
  final int inCart;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MenuRow({
    required this.item,
    required this.inCart,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (item.modifiers.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.modifiers.map((m) => m.name).join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                money.format(item.price),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              if (inCart > 0)
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$inCart',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                )
              else
                Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent bar showing the round being built, with the fire action.
class _CartBar extends ConsumerWidget {
  final OrderCart cart;
  final bool sending;
  final bool isSecondRound;
  final VoidCallback onReview;
  final VoidCallback onSend;

  const _CartBar({
    required this.cart,
    required this.sending,
    required this.isSecondRound,
    required this.onReview,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money = ref.watch(moneyProvider);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: sending ? null : onReview,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${cart.totalQuantity} item'
                              '${cart.totalQuantity == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.expand_less_rounded,
                                size: 18, color: scheme.onSurfaceVariant),
                          ],
                        ),
                        Text(
                          money.format(cart.subtotal),
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(sending
                    ? 'Sending'
                    : isSecondRound
                        ? 'Add to order'
                        : 'Send to kitchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'Nothing matches.\nAn item marked unavailable will not show here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
