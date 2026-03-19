import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../models/room.dart';
import '../models/expense.dart';
import '../models/guest.dart';

class InvoiceService {
  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final _dateFormat = DateFormat('MMM dd, yyyy');

  /// Generate a PDF folio for the guest
  Future<Uint8List> generateInvoice({
    required Booking booking,
    required Room room,
    required Guest guest,
    required List<Expense> expenses,
  }) async {
    final pdf = pw.Document();

    // As per requirement:
    // Subtotal = Room Amount + All Billable Expenses
    // Amount Paid = Total of Paid Amounts (We assume room rate is paid or billed another way, but for this context, user specified "amount paid should be the total of paid amounts")
    // Balance Due = Subtotal - Amount Paid.
    final billableExpenses = expenses.where((e) => e.isBillable && e.bookingId == booking.id).toList();

    // Calculate totals
    final totalExpensesAmount = billableExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final paidExpensesAmount = billableExpenses.where((e) => e.isPaid).fold(0.0, (sum, e) => sum + e.amount);
    
    // Upfront booking payment logic
    final bookingPaidAmount = booking.isPaid ? booking.totalAmount : 0.0;
    
    final subTotal = booking.totalAmount + totalExpensesAmount;
    final amountPaid = bookingPaidAmount + paidExpensesAmount;
    final balanceDue = subTotal - amountPaid;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('HOTREST MANAGEMENT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text('123 Luxury Avenue', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('contact@grandluxe.com | +1 (555) 123-4567', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('GUEST FOLIO / INVOICE', style: pw.TextStyle(fontSize: 20, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Folio #: ${booking.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('Date: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              
              // GUEST & STAY INFO
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(guest.fullName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text(guest.email, style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(guest.phone, style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('STAY DETAILS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('Room: ${room.roomNumber} - ${room.typeLabel}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Check-in: ${_dateFormat.format(booking.checkInDate)}'),
                        pw.Text('Check-out: ${_dateFormat.format(booking.checkOutDate)}'),
                        pw.Text('Nights: ${booking.nights}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // ITEMS TABLE
              pw.Table.fromTextArray(
              headers: ['Description', 'Qty', 'Unit Price', 'Total'],
              data: [
                [
                  'Room Accommodation (${booking.nights} nights @ ${_currencyFormat.format(booking.totalAmount / (booking.nights > 0 ? booking.nights : 1))})${booking.isPaid ? ' (PAID)' : ''}', 
                  '1', 
                  _currencyFormat.format(booking.totalAmount), 
                  _currencyFormat.format(booking.totalAmount)
                ],
                ...billableExpenses.map((e) => [
                  '${e.description}${e.isPaid ? ' (PAID)' : ''}', 
                  '1', 
                  _currencyFormat.format(e.amount), 
                  _currencyFormat.format(e.amount)
                ]).toList(),
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
              pw.SizedBox(height: 24),

              // TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(_currencyFormat.format(subTotal), style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Amount Paid:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(_currencyFormat.format(amountPaid), style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Divider(color: PdfColors.grey400),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('BALANCE DUE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                            pw.Text(_currencyFormat.format(balanceDue), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('Thank you for choosing HotRest Management.', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))),
              pw.Center(child: pw.Text('For inquiries, contact info@hotrestmanagement.com', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Display a preview / print dialog for the invoice
  Future<void> displayInvoicePdf({
    required Booking booking,
    required Room room,
    required Guest guest,
    required List<Expense> expenses,
  }) async {
    final pdfBytes = await generateInvoice(
      booking: booking,
      room: room,
      guest: guest,
      expenses: expenses,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Folio_${booking.id.substring(0, 8)}.pdf',
    );
  }
}
