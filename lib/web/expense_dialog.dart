import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../domain/entities/expense.dart';
import '../domain/entities/room.dart';
import '../domain/entities/booking.dart';
import '../domain/entities/guest.dart';
import '../services/booking_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import 'widgets/responsive_dialog.dart';

class ExpenseDialog extends ConsumerStatefulWidget {
  final Expense? expense;

  const ExpenseDialog({super.key, this.expense});

  @override
  ConsumerState<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  BookingService get _bookingService => ref.read(bookingServiceProvider);
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _uuid = const Uuid();

  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  List<Room> _rooms = [];
  List<Map<String, dynamic>> _bookings = [];

  // Form State
  late String _description;
  late double _amount;
  late ExpenseCategory _category;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _roomId;
  bool _isBillable = false;
  bool _isPaid = false;
  String? _bookingId;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _description = e?.description ?? '';
    _amount = e?.amount ?? 0.0;
    _category = e?.category ?? ExpenseCategory.other;
    _startDate = e?.date ?? DateTime.now();
    _endDate = e?.endDate;
    _roomId = e?.roomId;
    _isBillable = e?.isBillable ?? false;
    _isPaid = e?.isPaid ?? false;
    _bookingId = e?.bookingId;

    _loadData();
  }

  Future<void> _loadData() async {
    final rooms = await _bookingService.getAllRooms();
    final bookings = await _bookingService.getEnrichedBookings();
    
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _bookings = bookings;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate ?? _startDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.adminPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        // If start and end are the same day, we treat it as a single day expense
        if (picked.start.isAtSameMomentAs(picked.end)) {
          _endDate = null;
        } else {
          _endDate = picked.end;
        }
      });
    }
  }

  Future<void> _selectSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.adminPrimary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _endDate = null;
      });
    }
  }

  void _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Specific validation: Ensure billable expenses fall entirely within the stay period
    if (_isBillable && _bookingId != null) {
      try {
        final b = _bookings.firstWhere((b) => (b['booking'] as Booking).id == _bookingId);
        final booking = b['booking'] as Booking;

        // Strip time components for pure date comparison
        final stayStart = DateTime(booking.checkInDate.year, booking.checkInDate.month, booking.checkInDate.day);
        final stayEnd = DateTime(booking.checkOutDate.year, booking.checkOutDate.month, booking.checkOutDate.day);
        
        final expStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final expEnd = _endDate != null ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day) : expStart;

        if (expStart.isBefore(stayStart) || expEnd.isAfter(stayEnd)) {
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Expense dates must fall within the guest\'s stay period (${_dateFormat.format(stayStart)} to ${_dateFormat.format(stayEnd)}).',
                ),
                backgroundColor: AppTheme.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return; // Prevent saving
        }
      } catch (e) {
        // Fallback for safety if booking is not found locally
      }
    }

    final expense = Expense(
      id: widget.expense?.id ?? _uuid.v4(),
      description: _description,
      amount: _amount,
      category: _category,
      date: _startDate,
      endDate: _endDate,
      roomId: _roomId,
      isBillable: _isBillable,
      isPaid: _isBillable ? _isPaid : false,
      bookingId: _isBillable ? _bookingId : null,
    );

    try {
      if (widget.expense == null) {
        await _bookingService.addExpense(expense);
      } else {
        await _bookingService.updateExpense(expense);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        child: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isEdit = widget.expense != null;
    final dateDisplay = _endDate != null
        ? '${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate!)}'
        : _dateFormat.format(_startDate);

    return ResponsiveDialogNoScroll(
      maxWidth: 600,
      child: Container(
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Expense' : 'Log New Expense',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ROW 1: Description & Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: _description,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            onSaved: (val) => _description = val!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: _amount == 0 ? '' : _amount.toString(),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (double.tryParse(val) == null) return 'Invalid amount';
                              return null;
                            },
                            onSaved: (val) => _amount = double.parse(val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ROW 2: Category & Date
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ExpenseCategory>(
                            initialValue: _category,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: ExpenseCategory.values.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _category = val);
                            },
                            onSaved: (val) => _category = val!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: _endDate != null ? _selectDateRange : _selectSingleDate,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          dateDisplay,
                                          style: const TextStyle(fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_rounded, size: 20, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (_endDate == null) {
                                    _selectDateRange();
                                  } else {
                                    setState(() => _endDate = null);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _endDate == null ? 'Change to multi-day period' : 'Change to single day',
                                  style: TextStyle(fontSize: 11, color: AppTheme.adminPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ROW 3: Room optional link
                    DropdownButtonFormField<String?>(
                      initialValue: _roomId,
                      decoration: InputDecoration(
                        labelText: 'Link to Room (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Property-wide (No specific room)'),
                        ),
                        ..._rooms.map((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text('Room ${r.roomNumber} - ${r.typeLabel}'),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _roomId = val;
                          
                          // If a room is selected and the current booking doesn't match the new room, clear it
                          if (_bookingId != null && _roomId != null) {
                            try {
                              final currentBooking = _bookings.firstWhere((b) => (b['booking'] as Booking).id == _bookingId);
                              if ((currentBooking['booking'] as Booking).roomId != _roomId) {
                                _bookingId = null;
                              }
                            } catch (_) {
                              _bookingId = null;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // BILLING SECTION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isBillable ? AppTheme.warning.withValues(alpha: 0.05) : Colors.grey.shade50,
                        border: Border.all(color: _isBillable ? AppTheme.warning.withValues(alpha: 0.3) : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bill to Guest Folio', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Check this if this cost should be invoiced to a guest.'),
                            value: _isBillable,
                            activeColor: AppTheme.warning,
                            onChanged: (val) {
                              setState(() {
                                _isBillable = val ?? false;
                                if (!_isBillable) {
                                  _bookingId = null;
                                  _isPaid = false;
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (_isBillable) ...[
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mark as Paid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: const Text('Check this if the guest has already settled this specific expense.'),
                              value: _isPaid,
                              activeColor: AppTheme.success,
                              onChanged: (val) {
                                setState(() {
                                  _isPaid = val ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _bookingId,
                              decoration: InputDecoration(
                                labelText: 'Select Guest Booking',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (val) => _isBillable && (val == null || val.isEmpty) ? 'Must select a guest to bill' : null,
                              items: _bookings.where((b) {
                                final booking = b['booking'] as Booking;
                                // Only show bookings for the selected room, or all if no room is selected
                                if (_roomId != null && booking.roomId != _roomId) {
                                  return false;
                                }
                                // Only show active/checked-in guests or pending ones to bill them
                                return booking.status != BookingStatus.checkedOut && booking.status != BookingStatus.cancelled;
                              }).map((b) {
                                final booking = b['booking'] as Booking;
                                final guest = b['guest'] as Guest?;
                                final fullName = guest?.fullName ?? 'Unknown';
                                return DropdownMenuItem(
                                  value: booking.id,
                                  child: Text('$fullName (Check-in: ${_dateFormat.format(booking.checkInDate)})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _bookingId = val);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _saveExpense,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.adminPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEdit ? 'Save Changes' : 'Log Expense'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
