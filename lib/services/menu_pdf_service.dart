import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/menu_item.dart';
import '../providers/hotel_session.dart';

// ── Dark-theme palette ──────────────────────────────────────────────────────
const _kBg      = PdfColor(0.110, 0.110, 0.110); // #1C1C1C  page background
const _kCard    = PdfColor(0.157, 0.157, 0.157); // #282828  card / footer bg
const _kOrange  = PdfColor(0.976, 0.451, 0.086); // #F97316  orange accent
const _kWhite   = PdfColors.white;
const _kGray    = PdfColor(0.700, 0.700, 0.700); // #B3B3B3  secondary text
const _kDivider = PdfColor(0.250, 0.250, 0.250); // #404040  subtle separator
// ────────────────────────────────────────────────────────────────────────────

class MenuPdfService {

  Future<Uint8List?> _fetchLogoBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<Uint8List> generateMenuPdf({
    required List<MenuItem> items,
    HotelSettings? settings,
    bool includeUnavailable = false,
    String currencySymbol = '\$',
  }) async {
    final fmt      = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final pdf      = pw.Document();
    final propName = settings?.displayName.isNotEmpty == true
        ? settings!.displayName
        : 'Restaurant';
    final propAddress = settings?.address ?? '';
    final propPhone   = settings?.phone   ?? '';
    final logoBytes   = await _fetchLogoBytes(settings?.logoUrl ?? '');
    final logoImage   = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    // Filter & group
    final displayItems = includeUnavailable
        ? items
        : items.where((i) => i.isAvailable).toList();
    final categories = displayItems.map((i) => i.category).toSet().toList()..sort();
    final grouped = {
      for (final cat in categories)
        cat: displayItems.where((i) => i.category == cat).toList(),
    };

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _kBg),
          ),
        ),
        header: (ctx) => _pageHeader(ctx, propName, logoImage),
        footer: (ctx) => _pageFooter(ctx, propPhone, propAddress),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(40, 24, 40, 0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [

                // ── Hero title (appears first → always page 1) ────────────
                _titleBlock(propName),
                pw.SizedBox(height: 28),

                // ── Category sections ──────────────────────────────────────
                ...categories.expand((cat) => [
                  _categoryHeader(cat),
                  pw.SizedBox(height: 14),
                  _itemsGrid(grouped[cat]!, fmt, includeUnavailable),
                  pw.SizedBox(height: 24),
                ]),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Header (suppressed on page 1, minimal on continuations) ─────────────

  pw.Widget _pageHeader(
      pw.Context ctx, String propName, pw.MemoryImage? logoImage) {
    if (ctx.pageNumber == 1) return pw.SizedBox(height: 0);
    return pw.Container(
      color: _kCard,
      padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            if (logoImage != null) ...[
              pw.Container(
                width: 26,
                height: 26,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 8),
            ],
            pw.Text(
              propName.toUpperCase(),
              style: pw.TextStyle(
                color: _kWhite,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ]),
          pw.Text(
            'FOOD MENU',
            style: pw.TextStyle(
              color: _kOrange,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero title block ─────────────────────────────────────────────────────

  pw.Widget _titleBlock(String propName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'FOOD MENU',
            style: pw.TextStyle(
              color: _kWhite,
              fontSize: 44,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            propName,
            style: pw.TextStyle(
              color: _kGray,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.SizedBox(height: 18),
        // Orange accent underline
        pw.Center(
          child: pw.Container(width: 64, height: 3, color: _kOrange),
        ),
      ],
    );
  }

  // ─── Category header ──────────────────────────────────────────────────────

  pw.Widget _categoryHeader(String category) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _kOrange,
      child: pw.Text(
        category.toUpperCase(),
        style: pw.TextStyle(
          color: _kWhite,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // ─── Two-column item grid ─────────────────────────────────────────────────

  pw.Widget _itemsGrid(
      List<MenuItem> items, NumberFormat fmt, bool showUnavailableBadge) {
    final rows = <pw.Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final left  = items[i];
      final right = (i + 1 < items.length) ? items[i + 1] : null;
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: _itemEntry(left, fmt, showUnavailableBadge)),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: right != null
                  ? _itemEntry(right, fmt, showUnavailableBadge)
                  : pw.SizedBox(),
            ),
          ],
        ),
      );
    }
    return pw.Column(children: rows);
  }

  pw.Widget _itemEntry(
      MenuItem item, NumberFormat fmt, bool showUnavailableBadge) {
    final available = item.isAvailable;
    final nameFg    = available ? _kWhite  : _kGray;
    final priceFg   = available ? _kOrange : _kGray;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Name + price on same row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Flexible(
                child: pw.Text(
                  item.name,
                  style: pw.TextStyle(
                    color: nameFg,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Row(children: [
                pw.Text(
                  fmt.format(item.price),
                  style: pw.TextStyle(
                    color: priceFg,
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (!available && showUnavailableBadge) ...[
                  pw.SizedBox(width: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    color: _kDivider,
                    child: pw.Text(
                      'SOLD OUT',
                      style: pw.TextStyle(
                        color: _kGray,
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
          // Description
          if (item.description.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              item.description,
              style: pw.TextStyle(
                color: _kGray,
                fontSize: 8.5,
                fontStyle: pw.FontStyle.italic,
                lineSpacing: 1.2,
              ),
              maxLines: 2,
            ),
          ],
          pw.SizedBox(height: 6),
          pw.Container(height: 0.5, color: _kDivider),
        ],
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  pw.Widget _pageFooter(
      pw.Context ctx, String propPhone, String propAddress) {
    return pw.Column(
      children: [
        pw.Container(height: 2, color: _kOrange),
        pw.Container(
          color: _kCard,
          padding: const pw.EdgeInsets.fromLTRB(40, 10, 40, 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                if (propPhone.isNotEmpty) ...[
                  _contactBadge('☎  $propPhone'),
                  pw.SizedBox(width: 8),
                ],
                if (propAddress.isNotEmpty)
                  _contactBadge('⊙  $propAddress'),
              ]),
              pw.Text(
                'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.5, color: _kGray),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _contactBadge(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _kOrange,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: _kWhite,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Public entry point ───────────────────────────────────────────────────

  Future<void> displayMenuPdf({
    required List<MenuItem> items,
    HotelSettings? settings,
    bool includeUnavailable = false,
    String currencySymbol = '\$',
  }) async {
    final bytes = await generateMenuPdf(
      items: items,
      settings: settings,
      includeUnavailable: includeUnavailable,
      currencySymbol: currencySymbol,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Menu_${settings?.displayName ?? 'Restaurant'}.pdf',
    );
  }
}
