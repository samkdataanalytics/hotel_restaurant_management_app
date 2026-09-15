import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../domain/entities/restaurant_order.dart';
import '../../domain/table_bill.dart';

/// Paper the venue has loaded. 58mm and 80mm are what cheap thermal printers
/// come in; 72mm exists but is rare enough not to offer.
enum ReceiptPaper { mm58, mm80 }

extension ReceiptPaperX on ReceiptPaper {
  PaperSize get paperSize =>
      this == ReceiptPaper.mm58 ? PaperSize.mm58 : PaperSize.mm80;

  String get label => this == ReceiptPaper.mm58 ? '58mm' : '80mm';
}

/// Everything printed on a receipt that does not come from the order itself.
class ReceiptHeader {
  final String propertyName;
  final String? addressLine;
  final String? phone;
  final String currencySymbol;

  const ReceiptHeader({
    required this.propertyName,
    this.addressLine,
    this.phone,
    this.currencySymbol = '',
  });
}

/// Turns a settled table into ESC/POS bytes.
///
/// Separated from anything Bluetooth so the layout can be tested without a
/// printer — the transport is the part that needs hardware, the content is not.
///
/// Deliberately plain: no logo bitmap, no QR. A thermal printer renders those
/// slowly and inconsistently across the no-name models these venues actually
/// buy, and a receipt that takes six seconds holds up the next table.
class ReceiptBuilder {
  final ReceiptPaper paper;
  final CapabilityProfile profile;

  const ReceiptBuilder({required this.paper, required this.profile});

  /// Loads the default profile. Async because the package reads a bundled
  /// capability file.
  static Future<ReceiptBuilder> create({
    ReceiptPaper paper = ReceiptPaper.mm80,
  }) async =>
      ReceiptBuilder(
        paper: paper,
        profile: await CapabilityProfile.load(),
      );

  List<int> build({
    required ReceiptHeader header,
    required List<RestaurantOrder> orders,
    required TableBill bill,
    required String tableLabel,
    required DateTime settledAt,
    required bool chargedToRoom,
    String? roomLabel,
    double taxRate = 0,
    double serviceChargeRate = 0,
  }) {
    final g = Generator(paper.paperSize, profile);
    final bytes = <int>[];

    bytes.addAll(g.reset());

    // ── Header ──────────────────────────────────────────────────────────
    bytes.addAll(g.text(
      safe(header.propertyName),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    ));
    if (header.addressLine != null && header.addressLine!.isNotEmpty) {
      bytes.addAll(g.text(safe(header.addressLine!),
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (header.phone != null && header.phone!.isNotEmpty) {
      bytes.addAll(g.text(safe(header.phone!),
          styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(g.hr());
    bytes.addAll(g.row([
      PosColumn(text: safe(tableLabel), width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _timestamp(settledAt),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
    bytes.addAll(g.text(
      'Order${orders.length == 1 ? '' : 's'} '
      '${orders.map((o) => '#${o.orderNumber}').join(' ')}',
    ));
    bytes.addAll(g.hr());

    // ── Lines ───────────────────────────────────────────────────────────
    for (final order in orders) {
      for (final item in order.items) {
        if (item.isFullyRefunded) continue;

        bytes.addAll(g.row([
          PosColumn(text: '${item.activeQuantity}', width: 1),
          PosColumn(text: safe(item.menuItem.name), width: 7),
          PosColumn(
            text: _money(item.subtotal, header.currencySymbol),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));

        // Modifiers and notes are indented under their line so a guest
        // querying the bill can see what they were charged for.
        final modifiers = item.selectedModifiers.entries
            .map((e) => e.value.join(', '))
            .where((s) => s.isNotEmpty)
            .join(' · ');
        if (modifiers.isNotEmpty) {
          bytes.addAll(g.text(safe('  $modifiers')));
        }
        if (item.notes.isNotEmpty) {
          bytes.addAll(g.text(safe('  (${item.notes})')));
        }
      }
    }

    // ── Totals ──────────────────────────────────────────────────────────
    bytes.addAll(g.hr());
    bytes.addAll(_totalRow(g, 'Subtotal', bill.itemsTotal, header));
    if (bill.discountValue > 0) {
      bytes.addAll(_totalRow(g, 'Discount', -bill.discountValue, header));
    }
    if (taxRate > 0) {
      bytes.addAll(_totalRow(
          g, 'Tax ${(taxRate * 100).toStringAsFixed(0)}%', bill.tax, header));
    }
    if (serviceChargeRate > 0 && bill.serviceCharge > 0) {
      bytes.addAll(_totalRow(
        g,
        'Service ${(serviceChargeRate * 100).toStringAsFixed(0)}%'
        '${bill.hasMixedOrderTypes ? '*' : ''}',
        bill.serviceCharge,
        header,
      ));
    }
    bytes.addAll(g.hr(ch: '='));
    bytes.addAll(g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _money(bill.total, header.currencySymbol),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]));

    if (bill.hasMixedOrderTypes && serviceChargeRate > 0) {
      bytes.addAll(g.text('* service charge on dine-in items only',
          styles: const PosStyles(fontType: PosFontType.fontB)));
    }

    bytes.addAll(g.feed(1));
    bytes.addAll(g.text(
      chargedToRoom
          ? safe('CHARGED TO ROOM ${roomLabel ?? ''}'.trim())
          : 'PAID',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(g.feed(1));
    bytes.addAll(g.text('Thank you',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());

    return bytes;
  }

  /// A short page proving the printer works and the paper width is right.
  ///
  /// The ruler line is the point: if it wraps, the configured width is wrong.
  List<int> buildTestPage() {
    final g = Generator(paper.paperSize, profile);
    final bytes = <int>[];
    bytes.addAll(g.reset());
    bytes.addAll(g.text('HotRest',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        )));
    bytes.addAll(g.text(safe('Printer test - ${paper.label}'),
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.hr());
    bytes.addAll(g.text('1234567890' * 6));
    bytes.addAll(g.row([
      PosColumn(text: 'Left', width: 6),
      PosColumn(
          text: 'Right', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(g.hr(ch: '='));
    bytes.addAll(g.text('If the line above fits on one row,',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.text('the paper width is set correctly.',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  List<int> _totalRow(
    Generator g,
    String label,
    double value,
    ReceiptHeader header,
  ) =>
      g.row([
        PosColumn(text: label, width: 7),
        PosColumn(
          text: _money(value, header.currencySymbol),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

  /// Makes text safe for an ESC/POS printer.
  ///
  /// The generator encodes as Latin-1 and throws on anything outside it, so a
  /// menu item called "Crème Brûlée" is fine but a smart quote, an em dash or
  /// an emoji crashes the receipt. Menu names, modifiers and kitchen notes are
  /// all typed by staff, so this is not hypothetical — the common typographic
  /// characters are mapped to ASCII and anything still unencodable becomes '?'
  /// rather than taking the print down.
  static String safe(String input) {
    const replacements = {
      '\u2014': '-', // em dash
      '\u2013': '-', // en dash
      '\u2018': "'", // left single quote
      '\u2019': "'", // right single quote
      '\u201C': '"', // left double quote
      '\u201D': '"', // right double quote
      '\u2026': '...', // ellipsis
      '\u00A0': ' ', // non-breaking space
      '\u2022': '-', // bullet
      '\u20B9': 'Rs', // rupee
      '\u20AC': 'EUR', // euro
      '\u00A3': 'GBP', // pound sign is Latin-1 but prints unreliably
    };

    var out = input;
    replacements.forEach((from, to) => out = out.replaceAll(from, to));

    // Anything left outside Latin-1 cannot be encoded at all.
    return String.fromCharCodes(
      out.runes.map((r) => r <= 0xFF ? r : 0x3F),
    );
  }

  static String _money(double value, String symbol) =>
      safe('$symbol${value.toStringAsFixed(2)}');

  /// Local time, since a receipt is read where it was printed.
  static String _timestamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)} ${two(at.hour)}:${two(at.minute)}';
  }
}
