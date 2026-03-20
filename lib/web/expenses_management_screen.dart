import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/expense.dart';
import '../models/room.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../services/booking_service.dart';
import 'expense_dialog.dart';

class ExpensesManagementScreen extends StatefulWidget {
  const ExpensesManagementScreen({super.key});

  @override
  State<ExpensesManagementScreen> createState() => _ExpensesManagementScreenState();
}

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen> {
  final _bookingService = BookingService();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  String get _sym => Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';

  List<Expense> _expenses = [];
  List<Room> _rooms = [];
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final expenses = await _bookingService.getAllExpenses();
    final rooms = await _bookingService.getAllRooms();
    final bookings = await _bookingService.getEnrichedBookings();
    
    // Sort expenses strictly by most recent
    expenses.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _rooms = rooms;
      _bookings = bookings;
      _isLoading = false;
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete "${expense.description}"? This action cannot be undone.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _bookingService.deleteExpense(expense.id);
    _loadData(); // refresh list
  }
  
  void _openExpenseDialog([Expense? expense]) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => ExpenseDialog(
        expense: expense,
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  String _getRoomName(String? roomId) {
    if (roomId == null) return '-';
    try {
      return 'Room ${_rooms.firstWhere((r) => r.id == roomId).roomNumber}';
    } catch (_) {
      return 'Unknown ($roomId)';
    }
  }

  String _getGuestNameForBooking(String? bookingId) {
    if (bookingId == null) return '-';
    try {
      final b = _bookings.firstWhere((b) => (b['booking'] as Booking).id == bookingId);
      final guest = b['guest'] as Guest?;
      return guest?.fullName.split(' ').last ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.cleaning: return Icons.cleaning_services_rounded;
      case ExpenseCategory.maintenance: return Icons.build_rounded;
      case ExpenseCategory.utilities: return Icons.electric_bolt_rounded;
      case ExpenseCategory.supplies: return Icons.inventory_2_rounded;
      case ExpenseCategory.restaurant: return Icons.restaurant_rounded;
      case ExpenseCategory.other: return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Property Expenses', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Manage, categorize, and track operational costs and billables.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openExpenseDialog(),
                  icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  label: const Text('Log Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Main Table Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text('DESCRIPTION', style: _tableHeaderStyle())),
                          Expanded(flex: 2, child: Text('DATE / PERIOD', style: _tableHeaderStyle())),
                          Expanded(flex: 1, child: Text('ROOM', style: _tableHeaderStyle())),
                          Expanded(flex: 2, child: Text('BILLABLE TO', style: _tableHeaderStyle())),
                          Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('AMOUNT', style: _tableHeaderStyle()))),
                          const SizedBox(width: 80), // Actions padding
                        ],
                      ),
                    ),
                    if (_expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: Text('No expenses recorded yet', style: TextStyle(color: Colors.black54, fontSize: 16)),
                        ),
                      )
                    else
                      ..._expenses.map((expense) => _buildExpenseRow(expense)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    final bool isPeriod = expense.endDate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Info Block
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.adminPrimary.withValues(alpha: 0.1),
                  radius: 18,
                  child: Icon(_getCategoryIcon(expense.category), size: 18, color: AppTheme.adminPrimary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        expense.description,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expense.category.name.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.adminTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Date Block
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _dateFormat.format(expense.date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (isPeriod) ...[
                  const SizedBox(height: 2),
                  Text(
                    'to ${_dateFormat.format(expense.endDate!)}',
                    style: TextStyle(fontSize: 12, color: AppTheme.adminTextMuted),
                  ),
                ],
              ],
            ),
          ),

          // Room Link
          Expanded(
            flex: 1,
            child: Text(
              _getRoomName(expense.roomId),
              style: TextStyle(
                fontWeight: expense.roomId != null ? FontWeight.w600 : FontWeight.w400,
                color: expense.roomId != null ? Colors.black87 : Colors.black45,
              ),
            ),
          ),

          // Billable Link
          Expanded(
            flex: 2,
            child: expense.isBillable 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sell_rounded, size: 14, color: AppTheme.warning),
                        const SizedBox(width: 6),
                        Text(
                          _getGuestNameForBooking(expense.bookingId),
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.warning),
                        ),
                      ],
                    ),
                    if (expense.isPaid) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                        ),
                        child: Text('PAID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.success)),
                      ),
                    ],
                  ],
                )
              : Text('Internal', style: TextStyle(color: AppTheme.adminTextMuted)),
          ),

          // Amount
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_sym}${expense.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.danger,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.adminPrimary,
                  onPressed: () => _openExpenseDialog(expense),
                  tooltip: 'Edit Expense',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppTheme.danger,
                  onPressed: () => _deleteExpense(expense),
                  tooltip: 'Delete Expense',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppTheme.adminTextMuted,
      letterSpacing: 1.2,
    );
  }
}
