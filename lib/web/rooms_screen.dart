import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../app_theme.dart';
import '../providers/hotel_session.dart';
import '../models/room.dart';
import '../services/booking_service.dart';
import 'room_expenses_dialog.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _bookingService = BookingService();
  String get _sym => Provider.of<HotelSession>(context, listen: false).settings?.currencySymbol ?? '\$';
  List<Room> _rooms = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final rooms = await _bookingService.getAllRooms();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _isLoading = false;
    });
  }

  List<Room> get _filteredRooms {
    if (_filterStatus == 'all') return _rooms;
    return _rooms
        .where((r) => r.status.name == _filterStatus)
        .toList();
  }

  Future<void> _toggleStatus(Room room) async {
    if (room.status == RoomStatus.occupied) return;

    // If switching from maintenance → available, show confirmation
    if (room.status == RoomStatus.maintenance) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('End Maintenance?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room ${room.roomNumber} is currently under maintenance.',
                style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 14, height: 1.5),
              ),
              if (room.maintenanceStart != null && room.maintenanceEnd != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Scheduled: ${room.maintenanceStart!.day}/${room.maintenanceStart!.month}/${room.maintenanceStart!.year} — ${room.maintenanceEnd!.day}/${room.maintenanceEnd!.month}/${room.maintenanceEnd!.year}',
                  style: TextStyle(color: AppTheme.adminTextMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to mark this room as available? The maintenance period will be cleared.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: AppTheme.adminTextMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Make Available'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Clear maintenance dates and set available
      final updated = room.copyWith(
        status: RoomStatus.available,
        clearMaintenance: true,
      );
      await _bookingService.updateRoom(updated);
      setState(() {
        final index = _rooms.indexWhere((r) => r.id == room.id);
        if (index != -1) _rooms[index] = updated;
      });
      return;
    }

    final updated = await _bookingService.toggleRoomStatus(room);
    setState(() {
      final index = _rooms.indexWhere((r) => r.id == room.id);
      if (index != -1) _rooms[index] = updated;
    });
  }

  Future<void> _showAddRoomDialog() async {
    final result = await showDialog<Room>(
      context: context,
      builder: (context) => const _RoomFormDialog(title: 'Add New Room'),
    );
    if (result != null) {
      try {
        await _bookingService.addRoom(result);
        await _loadRooms();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditRoomDialog(Room room) async {
    final result = await showDialog<Room>(
      context: context,
      builder: (context) => _RoomFormDialog(title: 'Edit Room', room: room),
    );
    if (result != null) {
      await _bookingService.updateRoom(result);
      await _loadRooms();
    }
  }

  Future<void> _showDeleteConfirmation(Room room) async {
    if (room.status == RoomStatus.occupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot delete an occupied room'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Delete Room'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete room ${room.roomNumber}? This action cannot be undone.',
          style: TextStyle(
            color: AppTheme.adminTextMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.adminTextMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bookingService.deleteRoom(room.id);
      await _loadRooms();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableCount =
        _rooms.where((r) => r.status == RoomStatus.available).length;
    final occupiedCount =
        _rooms.where((r) => r.status == RoomStatus.occupied).length;
    final maintenanceCount =
        _rooms.where((r) => r.status == RoomStatus.maintenance).length;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room Management',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _loadRooms,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showAddRoomDialog,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.adminPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter pills
            Wrap(
              spacing: 8,
              children: [
                _filterChip('All', 'all', _rooms.length),
                _filterChip('Available', 'available', availableCount),
                _filterChip('Occupied', 'occupied', occupiedCount),
                _filterChip('Maintenance', 'maintenance', maintenanceCount),
              ],
            ),
            const SizedBox(height: 24),

            // Room grid
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 1100) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                }

                final rooms = _filteredRooms;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) => _roomCard(rooms[index]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String status, int count) {
    final isActive = _filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.adminPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.adminPrimary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.adminTextMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.adminTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomCard(Room room) {
    Color statusColor;
    IconData statusIcon;

    switch (room.status) {
      case RoomStatus.available:
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case RoomStatus.occupied:
        statusColor = AppTheme.adminPrimary;
        statusIcon = Icons.person;
        break;
      case RoomStatus.maintenance:
        statusColor = AppTheme.warning;
        statusIcon = Icons.build_circle_outlined;
        break;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleStatus(room),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room.roomNumber,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          room.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                room.typeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Floor ${room.floor}',
                    style: TextStyle(
                      color: AppTheme.adminTextMuted,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${_sym}${room.pricePerNight.toInt()} / night',
                    style: TextStyle(
                      color: AppTheme.adminPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Action buttons
              Row(
                children: [
                  if (room.status != RoomStatus.occupied)
                    Expanded(
                      child: Text(
                        'Tap to toggle status',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  _actionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit room',
                    color: AppTheme.adminPrimary,
                    onPressed: () => _showEditRoomDialog(room),
                  ),
                  const SizedBox(width: 4),
                  _actionIconButton(
                    icon: Icons.receipt_long_rounded,
                    tooltip: 'Manage expenses',
                    color: AppTheme.warning,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => RoomExpensesDialog(room: room),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _actionIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete room',
                    color: AppTheme.danger,
                    onPressed: () => _showDeleteConfirmation(room),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Add / Edit Room Dialog ─────────────────────────────────

class _RoomFormDialog extends StatefulWidget {
  final String title;
  final Room? room;

  const _RoomFormDialog({required this.title, this.room});

  @override
  State<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<_RoomFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomNumberController;
  late final TextEditingController _floorController;
  late final TextEditingController _priceController;
  late RoomType _selectedType;
  late RoomStatus _selectedStatus;
  DateTime? _maintenanceStart;
  DateTime? _maintenanceEnd;

  bool get _isEditing => widget.room != null;

  @override
  void initState() {
    super.initState();
    _roomNumberController =
        TextEditingController(text: widget.room?.roomNumber ?? '');
    _floorController =
        TextEditingController(text: widget.room?.floor.toString() ?? '');
    _priceController = TextEditingController(
        text: widget.room?.pricePerNight.toStringAsFixed(0) ?? '');
    _selectedType = widget.room?.type ?? RoomType.standard;
    _selectedStatus = widget.room?.status ?? RoomStatus.available;
    _maintenanceStart = widget.room?.maintenanceStart;
    _maintenanceEnd = widget.room?.maintenanceEnd;
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _floorController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickMaintenanceDate(bool isStart) async {
    final result = await showDatePicker(
      context: context,
      initialDate: (isStart ? _maintenanceStart : _maintenanceEnd) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.adminPrimary),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          _maintenanceStart = result;
          if (_maintenanceEnd == null || _maintenanceEnd!.isBefore(result)) {
            _maintenanceEnd = result.add(const Duration(days: 1));
          }
        } else {
          _maintenanceEnd = result;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStatus == RoomStatus.maintenance &&
        (_maintenanceStart == null || _maintenanceEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set maintenance period dates'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final room = Room(
      id: widget.room?.id ?? const Uuid().v4(),
      roomNumber: _roomNumberController.text.trim(),
      type: _selectedType,
      floor: int.parse(_floorController.text.trim()),
      status: _selectedStatus,
      pricePerNight: double.parse(_priceController.text.trim()),
      maintenanceStart: _selectedStatus == RoomStatus.maintenance ? _maintenanceStart : null,
      maintenanceEnd: _selectedStatus == RoomStatus.maintenance ? _maintenanceEnd : null,
    );
    Navigator.pop(context, room);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.adminPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isEditing
                            ? Icons.edit_rounded
                            : Icons.add_business_rounded,
                        color: AppTheme.adminPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Room Number
                TextFormField(
                  controller: _roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    hintText: 'e.g. 101',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Room number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Room Type dropdown
                DropdownButtonFormField<RoomType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Room Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: RoomType.values.map((type) {
                    String label;
                    switch (type) {
                      case RoomType.standard:
                        label = 'Standard';
                        break;
                      case RoomType.deluxe:
                        label = 'Deluxe';
                        break;
                      case RoomType.suite:
                        label = 'Suite';
                        break;
                    }
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                const SizedBox(height: 16),

                // Floor and Price side by side
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _floorController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Floor',
                          hintText: 'e.g. 1',
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price / Night (\$)',
                          hintText: 'e.g. 150',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status dropdown
                DropdownButtonFormField<RoomStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                  items: RoomStatus.values.map((status) {
                    String label;
                    switch (status) {
                      case RoomStatus.available:
                        label = 'Available';
                        break;
                      case RoomStatus.occupied:
                        label = 'Occupied';
                        break;
                      case RoomStatus.maintenance:
                        label = 'Maintenance';
                        break;
                    }
                    return DropdownMenuItem(value: status, child: Text(label));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
                // Maintenance period (conditionally shown)
                if (_selectedStatus == RoomStatus.maintenance) ...[
                  const SizedBox(height: 16),
                  Text(
                    'MAINTENANCE PERIOD',
                    style: TextStyle(
                      color: AppTheme.adminTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickMaintenanceDate(true),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                hintText: 'Select date',
                                prefixIcon: Icon(Icons.event_rounded, color: AppTheme.warning),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              controller: TextEditingController(
                                text: _maintenanceStart != null
                                    ? '${_maintenanceStart!.day}/${_maintenanceStart!.month}/${_maintenanceStart!.year}'
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _pickMaintenanceDate(false),
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                hintText: 'Select date',
                                prefixIcon: Icon(Icons.event_rounded, color: AppTheme.warning),
                                suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              ),
                              controller: TextEditingController(
                                text: _maintenanceEnd != null
                                    ? '${_maintenanceEnd!.day}/${_maintenanceEnd!.month}/${_maintenanceEnd!.year}'
                                    : '',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.adminTextMuted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: Icon(
                        _isEditing ? Icons.save_rounded : Icons.add_rounded,
                        size: 18,
                      ),
                      label: Text(_isEditing ? 'Save Changes' : 'Add Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.adminPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
