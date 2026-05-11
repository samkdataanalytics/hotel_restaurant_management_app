import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:intl/intl.dart';
import '../domain/entities/menu_item.dart';
import '../providers/hotel_session.dart';

/// Generates a styled HTML menu document and triggers a browser download.
/// Uses dart:js_interop + package:web — fully WASM-compatible (no dart:html).
///
/// The resulting .html file can be:
///   • Opened in any browser (copy → paste into Google Docs)
///   • Imported directly into Google Docs via File → Open
///   • Opened in Microsoft Word
class MenuDocService {
  void generateAndDownload({
    required List<MenuItem> items,
    HotelSettings? settings,
    bool includeUnavailable = false,
    String currencySymbol = '\$',
  }) {
    final fmt      = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final propName = settings?.displayName.isNotEmpty == true
        ? settings!.displayName
        : 'Restaurant';
    final address  = settings?.address ?? '';
    final phone    = settings?.phone   ?? '';
    final email    = settings?.email   ?? '';

    final displayItems = includeUnavailable
        ? items
        : items.where((i) => i.isAvailable).toList();
    final categories = displayItems.map((i) => i.category).toSet().toList()..sort();
    final grouped = {
      for (final cat in categories)
        cat: displayItems.where((i) => i.category == cat).toList(),
    };

    final buffer = StringBuffer();
    buffer.write(_head(propName));
    buffer.write(_heroSection(propName, address, phone, email));

    for (final cat in categories) {
      buffer.write(_categorySection(cat, grouped[cat]!, fmt, includeUnavailable));
    }

    buffer.write(_footer(propName, email));
    buffer.write('</body></html>');

    _downloadHtml(buffer.toString(), 'Menu_$propName.html');
  }

  // ─── WASM-safe download via package:web ───────────────────────────────────

  void _downloadHtml(String content, String filename) {
    // Build a Blob from the HTML string
    final blob = web.Blob(
      [content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final url    = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href     = url;
    anchor.download = filename;
    // Append → click → remove is required in some browsers
    web.document.body!.append(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);
  }

  // ─── HTML head + global styles ────────────────────────────────────────────

  String _head(String title) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Menu – $title</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: "Georgia", "Times New Roman", serif;
      background: #1c1c1c;
      color: #fff;
      max-width: 860px;
      margin: 0 auto;
      padding: 0 0 60px;
    }

    /* ── Header band ── */
    .header {
      background: #1A2540;
      padding: 24px 48px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .header-left .prop-name {
      font-family: Arial, sans-serif;
      font-weight: 700;
      font-size: 14px;
      letter-spacing: 1.5px;
      color: #fff;
      text-transform: uppercase;
    }
    .header-left .prop-meta {
      font-size: 11px;
      color: #8fa0b8;
      margin-top: 4px;
    }
    .header-right .menu-label {
      font-family: Arial, sans-serif;
      font-weight: 700;
      font-size: 22px;
      letter-spacing: 5px;
      color: #D4A853;
    }
    .stripe { display: flex; height: 3px; }
    .stripe-gold   { flex: 1; background: #D4A853; }
    .stripe-orange { flex: 1; background: #F97316; }

    /* ── Hero title ── */
    .hero {
      text-align: center;
      padding: 36px 48px 24px;
    }
    .hero h1 {
      font-family: Arial, sans-serif;
      font-size: 46px;
      font-weight: 900;
      letter-spacing: 4px;
      color: #fff;
    }
    .hero .restaurant-name {
      font-size: 15px;
      color: #aaa;
      margin-top: 10px;
      letter-spacing: 0.5px;
    }
    .hero .accent-line {
      width: 64px;
      height: 3px;
      background: #F97316;
      margin: 18px auto 0;
    }

    /* ── Category ── */
    .category-header {
      background: #F97316;
      padding: 10px 48px;
      font-family: Arial, sans-serif;
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: #fff;
      margin: 28px 0 0;
    }

    /* ── Item grid (2 columns) ── */
    .items-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0 24px;
      padding: 0 48px;
    }

    .item {
      padding: 12px 0;
      border-bottom: 1px solid #303030;
    }

    .item-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: 8px;
    }
    .item-name {
      font-family: Arial, sans-serif;
      font-weight: 700;
      font-size: 13px;
      color: #fff;
    }
    .item-name.unavailable { color: #666; }
    .item-price {
      font-family: Arial, sans-serif;
      font-weight: 700;
      font-size: 13px;
      color: #F97316;
      white-space: nowrap;
    }
    .item-price.unavailable { color: #666; }
    .item-desc {
      font-size: 11px;
      font-style: italic;
      color: #888;
      margin-top: 4px;
      line-height: 1.4;
    }
    .sold-badge {
      display: inline-block;
      font-family: Arial, sans-serif;
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 0.5px;
      background: #2a2a2a;
      color: #666;
      padding: 2px 6px;
      border-radius: 3px;
      margin-left: 6px;
      vertical-align: middle;
    }

    /* ── Footer ── */
    .footer {
      margin-top: 48px;
      padding: 12px 48px;
      border-top: 2px solid #F97316;
      background: #232323;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .footer-thanks {
      font-size: 11px;
      font-style: italic;
      color: #666;
    }
    .contact-badges { display: flex; gap: 8px; flex-wrap: wrap; }
    .badge {
      font-family: Arial, sans-serif;
      font-size: 10px;
      font-weight: 700;
      background: #F97316;
      color: #fff;
      padding: 5px 12px;
      border-radius: 20px;
    }

    @media print {
      body { background: #fff; color: #000; }
      .header { background: #1A2540; -webkit-print-color-adjust: exact; }
      .category-header { background: #F97316; -webkit-print-color-adjust: exact; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="header-left">
      <div class="prop-name">$title</div>
    </div>
    <div class="header-right">
      <div class="menu-label">MENU</div>
    </div>
  </div>
  <div class="stripe">
    <div class="stripe-gold"></div>
    <div class="stripe-orange"></div>
  </div>
''';

  // ─── Hero section ─────────────────────────────────────────────────────────

  String _heroSection(
      String name, String address, String phone, String email) {
    final meta = [
      if (address.isNotEmpty) address,
      if (phone.isNotEmpty) phone,
      if (email.isNotEmpty) email,
    ].join('&nbsp;&nbsp;·&nbsp;&nbsp;');

    return '''
  <div class="hero">
    <h1>FOOD MENU</h1>
    <div class="restaurant-name">$name${meta.isNotEmpty ? '<br><span style="font-size:12px;color:#777;">$meta</span>' : ''}</div>
    <div class="accent-line"></div>
  </div>
''';
  }

  // ─── Category section ─────────────────────────────────────────────────────

  String _categorySection(
    String category,
    List<MenuItem> items,
    NumberFormat fmt,
    bool showUnavailableBadge,
  ) {
    final buf = StringBuffer();
    buf.write('''
  <div class="category-header">${_esc(category)}</div>
  <div class="items-grid">
''');

    for (final item in items) {
      final unavailable = !item.isAvailable;
      final nameClass   = unavailable ? 'item-name unavailable' : 'item-name';
      final priceClass  = unavailable ? 'item-price unavailable' : 'item-price';
      final badge       = (unavailable && showUnavailableBadge)
          ? '<span class="sold-badge">SOLD OUT</span>'
          : '';

      buf.write('''
    <div class="item">
      <div class="item-row">
        <span class="$nameClass">${_esc(item.name)}$badge</span>
        <span class="$priceClass">${_esc(fmt.format(item.price))}</span>
      </div>
''');
      if (item.description.isNotEmpty) {
        buf.write(
            '      <div class="item-desc">${_esc(item.description)}</div>\n');
      }
      buf.write('    </div>\n');
    }

    buf.write('  </div>\n');
    return buf.toString();
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  String _footer(String propName, String email) {
    final badges = StringBuffer();
    if (email.isNotEmpty) {
      badges.write('<span class="badge">✉ ${_esc(email)}</span>');
    }
    return '''
  <div class="footer">
    <div class="footer-thanks">Thank you for dining at ${_esc(propName)}</div>
    <div class="contact-badges">${badges.toString()}</div>
  </div>
''';
  }

  // ─── HTML escape ──────────────────────────────────────────────────────────

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
