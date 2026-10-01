import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'order_cart.dart';
import '../../data/money.dart';

/// Reviews and edits the round before it is fired.
///
/// Returns the edited cart, or null if the sheet was dismissed without changes.
Future<OrderCart?> showCartSheet(
  BuildContext context, {
  required OrderCart cart,
}) {
  return showModalBottomSheet<OrderCart>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CartSheet(cart: cart),
  );
}

class _CartSheet extends ConsumerStatefulWidget {
  final OrderCart cart;
  const _CartSheet({required this.cart});

  @override
  ConsumerState<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<_CartSheet> {
  late OrderCart _cart = widget.cart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final money = ref.watch(moneyProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('This round',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text(
                  '${_cart.totalQuantity} item'
                  '${_cart.totalQuantity == 1 ? '' : 's'}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      'The round is empty.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final line = _cart.items[i];
                      final modifierText = line.selectedModifiers.entries
                          .map((e) => e.value.join(', '))
                          .where((s) => s.isNotEmpty)
                          .join(' · ');

                      return Dismissible(
                        key: ValueKey(line.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: scheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Icon(Icons.delete_outline_rounded,
                              color: scheme.onErrorContainer),
                        ),
                        onDismissed: (_) =>
                            setState(() => _cart = _cart.remove(line.id)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.menuItem.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (modifierText.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          modifierText,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    if (line.notes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_note_rounded,
                                                size: 15,
                                                color: scheme.primary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                line.notes,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: scheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        money.format(line.subtotal),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _CompactStepper(
                                quantity: line.quantity,
                                onChanged: (q) => setState(
                                  () => _cart = _cart.setQuantity(line.id, q),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Round total',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            )),
                        Text(
                          money.format(_cart.subtotal),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_cart),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _CompactStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => onChanged(quantity - 1),
          icon: Icon(
            quantity == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_circle_outline_rounded,
          ),
          color: quantity == 1 ? scheme.error : null,
          tooltip: quantity == 1 ? 'Remove' : 'One fewer',
        ),
        SizedBox(
          width: 26,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
          tooltip: 'One more',
        ),
      ],
    );
  }
}
