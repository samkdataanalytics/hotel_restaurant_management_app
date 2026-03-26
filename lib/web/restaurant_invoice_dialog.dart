import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/restaurant_order.dart';
import '../models/restaurant_table.dart';

// ─── Restaurant brand colors — sourced from AppTheme ─────────────────────────
const _kOrange = AppTheme.restaurantAccent;
const _kOrangeBg = AppTheme.restaurantAccentBg;

/// Full-page invoice dialog.
///
/// Pass [allOrders] when there are multiple tickets (parent + add-ons) to
/// render each ticket's items under a sub-header and combined totals.
class RestaurantInvoiceDialog extends StatelessWidget {
  final RestaurantOrder order;
  final RestaurantTable? table;

  /// When the session has add-on tickets, pass ALL settled orders here.
  /// The invoice will show every ticket's items combined with sub-headers.
  final List<RestaurantOrder>? allOrders;

  const RestaurantInvoiceDialog({
    super.key,
    required this.order,
    this.table,
    this.allOrders,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<HotelSession>(context, listen: false).settings;
    final sym = settings?.currencySymbol ?? '\$';
    final currency = NumberFormat.currency(symbol: sym, decimalDigits: 2);
    final dateF = DateFormat('MMM dd, yyyy  HH:mm');
    final isPreview = order.id == 'preview';
    // When allOrders is supplied, aggregate across all tickets; otherwise single order.
    final ordersToRender = allOrders != null && allOrders!.isNotEmpty
        ? allOrders!
        : [order];
    final isMultiTicket = ordersToRender.length > 1;

    // Items subtotal (before any discounts)
    final itemsTotal = ordersToRender.fold(0.0, (s, o) => s + o.itemsTotal);

    // Aggregate discounts across all tickets
    final totalDiscount = ordersToRender.fold(0.0, (s, o) => s + o.discountValue);
    final subtotal = itemsTotal - totalDiscount; // post-discount subtotal

    // Tax & service charge from property settings
    // Service charge only applies to dine-in orders (not takeaway)
    final isDineIn = ordersToRender.any((o) => o.type == OrderType.dineIn);
    final taxRate           = settings?.taxRate           ?? 0.0;
    final serviceChargeRate = isDineIn ? (settings?.serviceChargeRate ?? 0.0) : 0.0;
    final tax           = subtotal * taxRate;
    final serviceCharge = subtotal * serviceChargeRate;
    final grandTotal = subtotal + tax + serviceCharge;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─ Header buttons bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, size: 16, color: _kOrange),
                  const SizedBox(width: 8),
                  Text(isPreview ? 'Invoice Preview' : 'Invoice',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(foregroundColor: Colors.black45),
                  ),
                ],
              ),
            ),

            // ─ Invoice body (scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant header
                    Center(
                      child: Column(
                        children: [
                          if (settings?.logoUrl.isNotEmpty == true)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                settings!.logoUrl,
                                height: 64,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _DefaultLogoIcon(),
                              ),
                            )
                          else
                            _DefaultLogoIcon(),
                          const SizedBox(height: 10),
                          Text(
                              settings?.displayName.isNotEmpty == true
                                  ? settings!.displayName
                                  : 'Restaurant',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 4),
                          if (settings?.address.isNotEmpty == true || settings?.phone.isNotEmpty == true)
                            Text(
                              [
                                if (settings?.address.isNotEmpty == true) settings!.address,
                                if (settings?.phone.isNotEmpty == true) 'Tel: ${settings!.phone}',
                              ].join(' • '),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Invoice meta
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _meta(
                              isMultiTicket ? 'Orders' : 'Order #',
                              isPreview
                                  ? '—'
                                  : isMultiTicket
                                      ? ordersToRender
                                          .map((o) => '#${o.orderNumber}')
                                          .join(', ')
                                      : order.orderNumber,
                            ),
                          ),
                          Expanded(child: _meta('Date', dateF.format(order.createdAt))),
                          if (table != null)
                            Expanded(child: _meta('Table', table!.tableNumber)),
                          Expanded(child: _meta('Type', order.type == OrderType.dineIn ? 'Dine-in' : 'Takeaway')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items header
                    Row(
                      children: [
                        Expanded(flex: 4, child: _colHdr('Item')),
                        Expanded(child: _colHdr('Qty', align: TextAlign.center)),
                        Expanded(child: _colHdr('Price', align: TextAlign.end)),
                        Expanded(child: _colHdr('Total', align: TextAlign.end)),
                      ],
                    ),
                    const Divider(thickness: 1.5),

                    // Items — one section per ticket when multi-order, else flat list
                    ...ordersToRender.expand((o) {
                      final visibleItems =
                          o.items.where((i) => !i.isFullyRefunded).toList();
                      return [
                        if (isMultiTicket)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: o.parentOrderId != null
                                        ? Colors.teal.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    o.parentOrderId != null
                                        ? 'Add-On #${o.orderNumber}'
                                        : 'Ticket #${o.orderNumber}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: o.parentOrderId != null
                                          ? Colors.teal.shade700
                                          : Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...visibleItems.map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Row(
                                      children: [
                                        Text(
                                            item.menuItem.imageUrl.isNotEmpty
                                                ? item.menuItem.imageUrl
                                                : '🍽️',
                                            style: const TextStyle(
                                                fontSize: 18)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.menuItem.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 13)),
                                              if (item.refundedQuantity > 0)
                                                Text(
                                                  '${item.refundedQuantity} unit(s) refunded',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .orange.shade600),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                        '${item.activeQuantity}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        currency
                                            .format(item.menuItem.price),
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        currency.format(item.subtotal),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            )),
                      ]; // end per-ticket item list
                    }), // end expand

                    const Divider(thickness: 1.5),
                    const SizedBox(height: 8),

                    // Totals
                    _totalRow('Items Total', currency.format(itemsTotal)),
                    if (totalDiscount > 0) ...[
                      const SizedBox(height: 4),
                      _totalRow('Discount', '− ${currency.format(totalDiscount)}',
                          color: Colors.green.shade700),
                      const SizedBox(height: 4),
                      _totalRow('Subtotal', currency.format(subtotal)),
                    ],
                    if (taxRate > 0) ...[
                      const SizedBox(height: 4),
                      _totalRow(
                        'Tax (${(taxRate * 100).toStringAsFixed(0)}%)',
                        currency.format(tax),
                        muted: true,
                      ),
                    ],
                    if (serviceChargeRate > 0) ...[
                      const SizedBox(height: 4),
                      _totalRow(
                        'Service Charge (${(serviceChargeRate * 100).toStringAsFixed(0)}%)',
                        currency.format(serviceCharge),
                        muted: true,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kOrangeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GRAND TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(currency.format(grandTotal),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _kOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Payment status
                    if (!isPreview)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _paymentColor(ordersToRender.first.paymentStatus).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_paymentLabel(ordersToRender.first.paymentStatus),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _paymentColor(ordersToRender.first.paymentStatus),
                                  fontSize: 13)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('Thank you for dining with us!',
                          style: TextStyle(color: Colors.black38, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),

            // ─ Footer action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isPreview)
                    Text('Order #${order.orderNumber}',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _meta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _colHdr(String text, {TextAlign align = TextAlign.start}) {
    return Text(text,
        textAlign: align,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black45, letterSpacing: 0.5));
  }

  Widget _totalRow(String label, String value, {bool muted = false, Color? color}) {
    final textColor = color ?? (muted ? Colors.black38 : Colors.black87);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: muted ? Colors.black38 : Colors.black54)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                color: textColor)),
      ],
    );
  }

  Color _paymentColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid: return const Color(0xFF22C55E);
      case PaymentStatus.chargedToRoom: return const Color(0xFFF59E0B);
      case PaymentStatus.unpaid: return const Color(0xFFEF4444);
    }
  }

  String _paymentLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid: return 'PAID';
      case PaymentStatus.chargedToRoom: return 'CHARGED TO ROOM';
      case PaymentStatus.unpaid: return 'UNPAID';
    }
  }
}

class _DefaultLogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: _kOrangeBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.restaurant_rounded, color: _kOrange, size: 28),
    );
  }
}
