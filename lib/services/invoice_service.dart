import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/room.dart';
import '../models/expense.dart';
import '../models/guest.dart';
import '../providers/hotel_session.dart';

// ─── Brand palette ────────────────────────────────────────────────────────────
// Matches the app sidebar (#1A2540 navy + #D4A853 gold)
const _kNavy       = PdfColor(0.102, 0.145, 0.251); // #1A2540
const _kGold       = PdfColor(0.831, 0.659, 0.325); // #D4A853
const _kBg         = PdfColor(0.973, 0.980, 0.988); // #F8FAFC
const _kBorder     = PdfColor(0.886, 0.914, 0.941); // #E2E8F0
const _kText       = PdfColor(0.118, 0.161, 0.231); // #1E293B
const _kMuted      = PdfColor(0.392, 0.455, 0.545); // #647087
const _kHdrSub     = PdfColor(0.690, 0.729, 0.784); // subtle header sub-text
const _kGreen      = PdfColor(0.082, 0.725, 0.369); // #15B85E
const _kRed        = PdfColor(0.937, 0.267, 0.267); // #EF4444
const _kGreenBg    = PdfColor(0.941, 0.992, 0.957); // #F0FDF4
const _kGreenBdr   = PdfColor(0.525, 0.875, 0.647); // #86DFAC
const _kRedBg      = PdfColor(1.000, 0.945, 0.949); // #FFF1F2
const _kRedBdr     = PdfColor(0.996, 0.804, 0.827); // #FECDD3

// ─────────────────────────────────────────────────────────────────────────────

class InvoiceService {
  final _dateFmt  = DateFormat('MMM dd, yyyy');

  /// Fetches logo image bytes from [url]. Returns null on any error.
  Future<Uint8List?> _fetchLogoBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  /// Generate a PDF guest folio.
  Future<Uint8List> generateInvoice({
    required Booking booking,
    required Room room,
    required Guest guest,
    required List<Expense> expenses,
    String currencySymbol = '\$',
    HotelSettings? settings,
  }) async {
    final fmt = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    final pdf = pw.Document();

    // ── Financial calculations ──────────────────────────────────────────────
    final billable      = expenses.where((e) => e.isBillable && e.bookingId == booking.id).toList();
    final totalExpenses = billable.fold(0.0, (s, e) => s + e.amount);
    final paidExpenses  = billable.where((e) => e.isPaid).fold(0.0, (s, e) => s + e.amount);
    final bookingPaid   = booking.isPaid ? booking.totalAmount : 0.0;
    final subTotal      = booking.totalAmount + totalExpenses;
    final amountPaid    = bookingPaid + paidExpenses;
    final balanceDue    = subTotal - amountPaid;
    final isFullyPaid   = balanceDue <= 0.005; // tolerance for float

    // ── Property branding ───────────────────────────────────────────────────
    final propName    = settings?.displayName.isNotEmpty == true ? settings!.displayName : 'Property';
    final propAddress = settings?.address ?? '';
    final propPhone   = settings?.phone   ?? '';
    final propEmail   = settings?.email   ?? '';
    final logoBytes   = await _fetchLogoBytes(settings?.logoUrl ?? '');
    final logoImage   = logoBytes != null ? pw.MemoryImage(logoBytes) : null;
    final folioId     = booking.id.substring(0, 8).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [

            // ╔══════════════════════════════════════════════════════════════╗
            // ║  1. NAVY HEADER BANNER                                      ║
            // ╚══════════════════════════════════════════════════════════════╝
            pw.Container(
              color: _kNavy,
              padding: const pw.EdgeInsets.fromLTRB(40, 26, 40, 26),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Left: logo + property info
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(
                          width: 52,
                          height: 52,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 14),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            propName.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          if (propAddress.isNotEmpty)
                            pw.Text(
                              propAddress,
                              style: const pw.TextStyle(color: _kHdrSub, fontSize: 8),
                            ),
                          if (propPhone.isNotEmpty || propEmail.isNotEmpty)
                            pw.Text(
                              [
                                if (propPhone.isNotEmpty) propPhone,
                                if (propEmail.isNotEmpty) propEmail,
                              ].join('   ·   '),
                              style: const pw.TextStyle(color: _kHdrSub, fontSize: 8),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Right: folio title + meta
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'GUEST FOLIO',
                        style: pw.TextStyle(
                          color: _kGold,
                          fontSize: 15,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                      pw.SizedBox(height: 7),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: const PdfColor(1, 1, 1, 0.1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '# $folioId',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Issued: ${_dateFmt.format(DateTime.now())}',
                        style: const pw.TextStyle(color: _kHdrSub, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 2. GOLD ACCENT BAR ─────────────────────────────────────────
            pw.Container(height: 4, color: _kGold),

            // ── 3. BODY ────────────────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(40, 26, 40, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [

                    // ── 3a. Billed To + Stay Details ──────────────────────
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: _infoCard(
                            label: 'BILLED TO',
                            children: [
                              pw.Text(
                                guest.fullName,
                                style: pw.TextStyle(
                                  color: _kText,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (guest.email.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(guest.email,
                                    style: const pw.TextStyle(fontSize: 9, color: _kMuted)),
                              ],
                              if (guest.phone.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(guest.phone,
                                    style: const pw.TextStyle(fontSize: 9, color: _kMuted)),
                              ],
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: _infoCard(
                            label: 'STAY DETAILS',
                            children: [
                              pw.Text(
                                'Room ${room.roomNumber}  ·  ${room.typeLabel}',
                                style: pw.TextStyle(
                                  color: _kText,
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              _detailRow('Check-in',  _dateFmt.format(booking.checkInDate)),
                              _detailRow('Check-out', _dateFmt.format(booking.checkOutDate)),
                              _detailRow(
                                'Duration',
                                '${booking.nights} night${booking.nights == 1 ? '' : 's'}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 22),

                    // ── 3b. Section label ─────────────────────────────────
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 3, height: 13, color: _kGold),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          'CHARGES',
                          style: pw.TextStyle(
                            color: _kNavy,
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    // ── 3c. Charges table ─────────────────────────────────
                    _buildChargesTable(booking, billable, fmt),
                    pw.SizedBox(height: 20),

                    // ── 3d. Totals + payment status ───────────────────────
                    _buildTotals(subTotal, amountPaid, balanceDue, isFullyPaid, fmt),

                    pw.Spacer(),

                    // ── 3e. Footer ────────────────────────────────────────
                    pw.Container(height: 1, color: _kGold),
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        'Thank you for choosing $propName. We look forward to welcoming you again.',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: _kMuted,
                        ),
                      ),
                    ),
                    if (propEmail.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Center(
                        child: pw.Text(
                          'For inquiries: $propEmail',
                          style: const pw.TextStyle(fontSize: 8, color: _kBorder),
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ─── Shared helper widgets ───────────────────────────────────────────────────

  pw.Widget _infoCard({
    required String label,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _kBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _kBorder, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _kGold,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _kMuted)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _kText,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildChargesTable(
    Booking booking,
    List<Expense> expenses,
    NumberFormat fmt,
  ) {
    final nightRate = booking.totalAmount / (booking.nights > 0 ? booking.nights : 1);

    // Build row data: [description, qty, unitPrice, total, isPaid]
    final rowData = <Map<String, dynamic>>[
      {
        'desc':   'Room Accommodation'
                  ' (${booking.nights} night${booking.nights == 1 ? '' : 's'}'
                  ' × ${fmt.format(nightRate)} / night)',
        'qty':    '1',
        'price':  fmt.format(booking.totalAmount),
        'total':  fmt.format(booking.totalAmount),
        'isPaid': booking.isPaid,
      },
      ...expenses.map((e) => {
        'desc':   e.description,
        'qty':    '1',
        'price':  fmt.format(e.amount),
        'total':  fmt.format(e.amount),
        'isPaid': e.isPaid,
      }),
    ];

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(4.2),
        1: pw.FlexColumnWidth(0.7),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _kBorder, width: 0.5),
      ),
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kNavy),
          children: [
            _th('DESCRIPTION'),
            _th('QTY', align: pw.TextAlign.center),
            _th('UNIT PRICE', align: pw.TextAlign.right),
            _th('AMOUNT', align: pw.TextAlign.right),
          ],
        ),
        // Data rows with alternating shade
        ...rowData.asMap().entries.map((entry) {
          final idx    = entry.key;
          final row    = entry.value;
          final isPaid = row['isPaid'] as bool;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: idx.isEven ? PdfColors.white : _kBg,
            ),
            children: [
              _td(
                '${row['desc']}${isPaid ? '  ✓ paid' : ''}',
                align: pw.TextAlign.left,
                color: isPaid ? _kMuted : _kText,
              ),
              _td(row['qty'] as String, align: pw.TextAlign.center),
              _td(row['price'] as String, align: pw.TextAlign.right),
              _td(row['total'] as String,
                  align: pw.TextAlign.right,
                  bold: true),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  pw.Widget _td(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool bold = false,
    PdfColor color = _kText,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildTotals(
    double subTotal,
    double amountPaid,
    double balanceDue,
    bool isFullyPaid,
    NumberFormat fmt,
  ) {
    final statusBg  = isFullyPaid ? _kGreenBg  : _kRedBg;
    final statusBdr = isFullyPaid ? _kGreenBdr  : _kRedBdr;
    final statusClr = isFullyPaid ? _kGreen     : _kRed;
    final statusLbl = isFullyPaid ? 'PAID IN FULL' : 'BALANCE DUE';
    final statusAmt = isFullyPaid
        ? fmt.format(subTotal)
        : fmt.format(balanceDue);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.SizedBox(
          width: 230,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Subtotal line
              _summaryLine('Subtotal', fmt.format(subTotal)),
              pw.SizedBox(height: 5),
              // Amount paid line (only if something was paid)
              if (amountPaid > 0) ...[
                _summaryLine(
                  'Amount Paid',
                  '− ${fmt.format(amountPaid)}',
                  valueColor: _kGreen,
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 0.5, color: _kBorder),
                pw.SizedBox(height: 10),
              ],
              // Status badge (PAID IN FULL / BALANCE DUE)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: pw.BoxDecoration(
                  color: statusBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: statusBdr, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      statusLbl,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: statusClr,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      statusAmt,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: statusClr,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _summaryLine(
    String label,
    String value, {
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _kMuted)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            color: valueColor ?? _kText,
            fontWeight:
                valueColor != null ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────

  /// Display a print/preview dialog for the guest folio.
  Future<void> displayInvoicePdf({
    required Booking booking,
    required Room room,
    required Guest guest,
    required List<Expense> expenses,
    String currencySymbol = '\$',
    HotelSettings? settings,
  }) async {
    final pdfBytes = await generateInvoice(
      booking:        booking,
      room:           room,
      guest:          guest,
      expenses:       expenses,
      currencySymbol: currencySymbol,
      settings:       settings,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'Folio_${booking.id.substring(0, 8)}.pdf',
    );
  }
}
