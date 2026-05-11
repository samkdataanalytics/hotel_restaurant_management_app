import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/staff_shift.dart';
import '../domain/entities/staff_permission.dart';
import '../services/shift_service.dart';
import '../providers/service_providers.dart';
import '../providers/app_auth_provider.dart';
import 'widgets/responsive_dialog.dart';

// ─── Accent colours for the TEAM section ─────────────────────────────────────

const _kAccent   = Color(0xFF818CF8); // indigo-400
const _kAccentBg = Color(0xFFF5F3FF);

// ─── Role colour map ──────────────────────────────────────────────────────────

const Map<String, Color> _kRoleColor = {
  'manager':     Color(0xFF2563EB),
  'front_desk':  Color(0xFF0891B2),
  'housekeeping':Color(0xFF059669),
  'kitchen':     Color(0xFFF97316),
  'security':    Color(0xFF7C3AED),
  'maintenance': Color(0xFF92400E),
};

Color _roleColor(String role) =>
    _kRoleColor[role.toLowerCase()] ?? const Color(0xFF64748B);

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffScheduleScreen extends ConsumerStatefulWidget {
  const StaffScheduleScreen({super.key});

  @override
  ConsumerState<StaffScheduleScreen> createState() =>
      _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends ConsumerState<StaffScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  DateTime _weekOf = ShiftService.weekStart(DateTime.now());
  ShiftService? _svc;

  List<StaffShift> _shifts  = [];
  List<TimeRecord> _records = [];
  TimeRecord? _activeRecord;
  bool _loadingShifts  = true;
  bool _loadingRecords = true;

  // Staff list for the Add Shift dropdown
  List<PropertyStaffMember> _staff = [];

  // Time-records filter
  String? _filterUserId; // null = all staff (managers only)

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() { if (_tab.indexIsChanging) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final hotelId = ref.read(activePropertyProvider)?.id;
    if (hotelId == null) return;
    _svc = ShiftService(hotelId);
    await Future.wait([_loadShifts(), _loadRecords(), _loadStaff()]);
  }

  Future<void> _loadShifts() async {
    if (_svc == null) return;
    setState(() => _loadingShifts = true);
    try {
      final days = ShiftService.weekDays(_weekOf);
      final result = await _svc!.getShiftsForRange(days.first, days.last);
      if (mounted) setState(() => _shifts = result);
    } catch (_) {
      // Table may not exist yet — silently show empty list
    } finally {
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  Future<void> _loadRecords() async {
    if (_svc == null) return;
    setState(() => _loadingRecords = true);
    try {
      final from = _weekOf;
      final to   = _weekOf.add(const Duration(days: 6, hours: 23, minutes: 59));
      final result = await _svc!.getTimeRecords(
          from: from, to: to, staffUserId: _filterUserId);
      final active = await _svc!.getMyActiveRecord();
      if (mounted) {
        setState(() {
          _records = result;
          _activeRecord = active;
        });
      }
    } catch (_) {
      // Silently ignore until migration is applied
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  Future<void> _loadStaff() async {
    final hotelId = ref.read(activePropertyProvider)?.id;
    if (hotelId == null) return;
    try {
      final list = await ref.read(staffServiceProvider).getPropertyStaff(hotelId);
      if (mounted) setState(() => _staff = list);
    } catch (_) {}
  }

  void _prevWeek() {
    setState(() => _weekOf = _weekOf.subtract(const Duration(days: 7)));
    _loadShifts();
    _loadRecords();
  }

  void _nextWeek() {
    setState(() => _weekOf = _weekOf.add(const Duration(days: 7)));
    _loadShifts();
    _loadRecords();
  }

  bool get _isManager => ref.watch(isPropertyManagerProvider);

  // ── Clock In / Out ────────────────────────────────────────────────────────

  Future<void> _clockIn() async {
    if (_svc == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    String name = '';
    if (uid != null) {
      final me = _staff.where((s) => s.userId == uid).firstOrNull;
      name = me?.fullName ?? '';
    }
    try {
      await _svc!.clockIn(staffName: name);
      await _loadRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clock-in failed: $e')),
        );
      }
    }
  }

  Future<void> _clockOut() async {
    if (_svc == null || _activeRecord == null) return;
    try {
      await _svc!.clockOut(_activeRecord!.id);
      await _loadRecords();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clock-out failed: $e')),
        );
      }
    }
  }

  // ── Shift dialogs ─────────────────────────────────────────────────────────

  Future<void> _showAddShift(DateTime date) async {
    if (_svc == null || !_isManager) return;
    final result = await showDialog<StaffShift>(
      context: context,
      builder: (_) => _ShiftDialog(
        initialDate: date,
        staff: _staff,
        hotelId: ref.read(activePropertyProvider)!.id,
      ),
    );
    if (result != null) {
      try {
        await _svc!.addShift(result);
        await _loadShifts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save shift: $e')),
          );
        }
      }
    }
  }

  Future<void> _showEditShift(StaffShift shift) async {
    if (_svc == null || !_isManager) return;
    final result = await showDialog<StaffShift>(
      context: context,
      builder: (_) => _ShiftDialog(
        existing: shift,
        initialDate: shift.shiftDate,
        staff: _staff,
        hotelId: shift.hotelId,
      ),
    );
    if (result != null) {
      try {
        await _svc!.updateShift(result);
        await _loadShifts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update shift: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteShift(StaffShift shift) async {
    if (_svc == null || !_isManager) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text(
            'Remove ${shift.staffName}\'s shift on '
            '${DateFormat('EEE, MMM d').format(shift.shiftDate)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok == true) {
      await _svc!.deleteShift(shift.id);
      await _loadShifts();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final days = ShiftService.weekDays(_weekOf);
    final weekLabel =
        '${DateFormat('MMM d').format(days.first)} – '
        '${DateFormat('MMM d, yyyy').format(days.last)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kAccentBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: _kAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift Schedule',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B))),
                        Text('Schedule shifts and track working hours',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tab,
                  labelColor: _kAccent,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: _kAccent,
                  indicatorWeight: 2,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Schedule'),
                    Tab(text: 'Time Tracking'),
                  ],
                ),
              ],
            ),
          ),

          // ── Week navigation bar ─────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            child: Row(
              children: [
                _weekNavBtn(Icons.chevron_left_rounded, _prevWeek),
                const SizedBox(width: 12),
                Text(weekLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                const SizedBox(width: 12),
                _weekNavBtn(Icons.chevron_right_rounded, _nextWeek),
                const Spacer(),
                if (_tab.index == 0 && _isManager)
                  FilledButton.icon(
                    onPressed: () => _showAddShift(DateTime.now()),
                    style: FilledButton.styleFrom(
                        backgroundColor: _kAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Shift',
                        style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Tab bodies ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ScheduleTab(
                  days: days,
                  shifts: _shifts,
                  loading: _loadingShifts,
                  isManager: _isManager,
                  onAddShift: _showAddShift,
                  onEditShift: _showEditShift,
                  onDeleteShift: _deleteShift,
                ),
                _TimeTrackingTab(
                  records: _records,
                  activeRecord: _activeRecord,
                  loading: _loadingRecords,
                  isManager: _isManager,
                  staff: _staff,
                  filterUserId: _filterUserId,
                  onFilterChanged: (uid) {
                    setState(() => _filterUserId = uid);
                    _loadRecords();
                  },
                  onClockIn: _clockIn,
                  onClockOut: _clockOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekNavBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF475569)),
        ),
      );
}

// ─── Schedule Tab ─────────────────────────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  final List<DateTime> days;
  final List<StaffShift> shifts;
  final bool loading;
  final bool isManager;
  final void Function(DateTime) onAddShift;
  final void Function(StaffShift) onEditShift;
  final void Function(StaffShift) onDeleteShift;

  const _ScheduleTab({
    required this.days,
    required this.shifts,
    required this.loading,
    required this.isManager,
    required this.onAddShift,
    required this.onEditShift,
    required this.onDeleteShift,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: days.length,
      itemBuilder: (_, i) {
        final day = days[i];
        final dayShifts = shifts
            .where((s) =>
                s.shiftDate.year == day.year &&
                s.shiftDate.month == day.month &&
                s.shiftDate.day == day.day)
            .toList();
        final isToday = _isToday(day);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isToday
                      ? _kAccent.withValues(alpha: 0.4)
                      : const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            DateFormat('EEE, MMM d').format(day),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        )
                      else
                        Text(
                          DateFormat('EEEE, MMM d').format(day),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                        ),
                      const Spacer(),
                      Text('${dayShifts.length} shift${dayShifts.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                      if (isManager) ...[
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => onAddShift(day),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kAccentBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 14, color: _kAccent),
                                SizedBox(width: 3),
                                Text('Add',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _kAccent)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dayShifts.isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      'No shifts scheduled',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                  )
                else
                  ...dayShifts.asMap().entries.map((e) {
                    final idx = e.key;
                    final shift = e.value;
                    return Column(
                      children: [
                        if (idx > 0)
                          const Divider(height: 1, indent: 16),
                        _ShiftRow(
                          shift: shift,
                          isManager: isManager,
                          onEdit: () => onEditShift(shift),
                          onDelete: () => onDeleteShift(shift),
                        ),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ─── Shift row ────────────────────────────────────────────────────────────────

class _ShiftRow extends StatelessWidget {
  final StaffShift shift;
  final bool isManager;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftRow({
    required this.shift,
    required this.isManager,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _roleColor(shift.role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(shift.staffName),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.staffName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _roleLabel(shift.role),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color),
                      ),
                    ),
                    if (shift.status != ShiftStatus.scheduled) ...[
                      const SizedBox(width: 6),
                      _StatusChip(shift.status),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${shift.startTime} – ${shift.endTime}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
              Text(shift.durationLabel,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),

          // Actions
          if (isManager) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  size: 17, color: Color(0xFF94A3B8)),
              onPressed: onEdit,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 17, color: Color(0xFFEF4444)),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _roleLabel(String role) =>
      role.replaceAll('_', ' ').split(' ')
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1)}'
              : '')
          .join(' ');
}

// ─── Status chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final ShiftStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      ShiftStatus.completed  => ('Completed', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      ShiftStatus.cancelled  => ('Cancelled', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      ShiftStatus.scheduled  => ('Scheduled', const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Time Tracking Tab ────────────────────────────────────────────────────────

class _TimeTrackingTab extends StatelessWidget {
  final List<TimeRecord> records;
  final TimeRecord? activeRecord;
  final bool loading;
  final bool isManager;
  final List<PropertyStaffMember> staff;
  final String? filterUserId;
  final void Function(String?) onFilterChanged;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _TimeTrackingTab({
    required this.records,
    required this.activeRecord,
    required this.loading,
    required this.isManager,
    required this.staff,
    required this.filterUserId,
    required this.onFilterChanged,
    required this.onClockIn,
    required this.onClockOut,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('h:mm a');
    final dateFmt = DateFormat('EEE, MMM d');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Clock-In card ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activeRecord != null
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activeRecord != null
                        ? Icons.timer_rounded
                        : Icons.timer_off_rounded,
                    color: activeRecord != null
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF94A3B8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeRecord != null ? 'Currently Clocked In' : 'Not Clocked In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: activeRecord != null
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      if (activeRecord != null)
                        Text(
                          'Since ${timeFmt.format(activeRecord!.clockIn)}  ·  '
                          '${_elapsed(activeRecord!.clockIn)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                if (activeRecord != null)
                  FilledButton.icon(
                    onPressed: onClockOut,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444)),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Clock Out'),
                  )
                else
                  FilledButton.icon(
                    onPressed: onClockIn,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A)),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Clock In'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Records header + filter ────────────────────────────────────
          Row(
            children: [
              const Text('Time Records',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const Spacer(),
              if (isManager && staff.isNotEmpty)
                _StaffFilter(
                  staff: staff,
                  selectedId: filterUserId,
                  onChanged: onFilterChanged,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Records list ───────────────────────────────────────────────
          if (loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else if (records.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 40, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 10),
                    Text(
                      filterUserId != null
                          ? 'No records for selected staff this week'
                          : 'No time records this week',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: records.asMap().entries.map((e) {
                  final idx = e.key;
                  final rec = e.value;
                  final color = _roleColor('staff');
                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, indent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _initials(rec.staffName),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name + date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rec.staffName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B))),
                                  Text(dateFmt.format(rec.clockIn),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            // Clock in/out
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.login_rounded,
                                        size: 12, color: Color(0xFF22C55E)),
                                    const SizedBox(width: 4),
                                    Text(timeFmt.format(rec.clockIn),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (rec.clockOut != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.logout_rounded,
                                          size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(timeFmt.format(rec.clockOut!),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF334155))),
                                    ],
                                  )
                                else
                                  const Text('Active',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF16A34A),
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Duration
                            Container(
                              width: 60,
                              alignment: Alignment.centerRight,
                              child: Text(
                                rec.durationLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: rec.isActive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _elapsed(DateTime since) {
    final diff = DateTime.now().difference(since);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${m}m elapsed';
    if (m == 0) return '${h}h elapsed';
    return '${h}h ${m}m elapsed';
  }
}

// ─── Staff filter dropdown ────────────────────────────────────────────────────

class _StaffFilter extends StatelessWidget {
  final List<PropertyStaffMember> staff;
  final String? selectedId;
  final void Function(String?) onChanged;

  const _StaffFilter({
    required this.staff,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          hint: const Text('All Staff',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          icon: const Icon(Icons.expand_more_rounded,
              size: 18, color: Color(0xFF94A3B8)),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Staff'),
            ),
            ...staff.map((s) => DropdownMenuItem<String?>(
                  value: s.userId,
                  child: Text(s.fullName),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Add / Edit Shift Dialog ──────────────────────────────────────────────────

class _ShiftDialog extends StatefulWidget {
  final StaffShift? existing;
  final DateTime initialDate;
  final List<PropertyStaffMember> staff;
  final String hotelId;

  const _ShiftDialog({
    this.existing,
    required this.initialDate,
    required this.staff,
    required this.hotelId,
  });

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  late DateTime _date;
  PropertyStaffMember? _selectedStaff;
  late String _startTime;
  late String _endTime;
  late String _role;
  late String _notes;
  late ShiftStatus _status;

  final _notesCtrl = TextEditingController();

  static const _roles = [
    'staff',
    'manager',
    'front_desk',
    'housekeeping',
    'kitchen',
    'security',
    'maintenance',
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _date       = ex?.shiftDate ?? widget.initialDate;
    _startTime  = ex?.startTime ?? '09:00';
    _endTime    = ex?.endTime   ?? '17:00';
    _role       = ex?.role      ?? 'staff';
    _notes      = ex?.notes     ?? '';
    _status     = ex?.status    ?? ShiftStatus.scheduled;
    _notesCtrl.text = _notes;

    if (ex != null) {
      _selectedStaff = widget.staff
          .where((s) => s.userId == ex.staffUserId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = _parseTime(isStart ? _startTime : _endTime);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => isStart ? _startTime = formatted : _endTime = formatted);
  }

  static TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _submit() {
    if (_selectedStaff == null) return;
    final shift = StaffShift(
      id:           widget.existing?.id ?? const Uuid().v4(),
      hotelId:      widget.hotelId,
      staffUserId:  _selectedStaff!.userId,
      staffName:    _selectedStaff!.fullName,
      shiftDate:    _date,
      startTime:    _startTime,
      endTime:      _endTime,
      role:         _role,
      notes:        _notesCtrl.text.trim(),
      status:       _status,
      createdAt:    widget.existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, shift);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return ResponsiveDialog(
      maxWidth: 420,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Shift' : 'Add Shift',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 20),

              // Staff
              _label('Staff Member'),
              DropdownButtonFormField<PropertyStaffMember>(
                initialValue: _selectedStaff,
                hint: const Text('Select staff member'),
                decoration: _inputDec(),
                items: widget.staff.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.fullName),
                    )).toList(),
                onChanged: (v) => setState(() => _selectedStaff = v),
              ),
              const SizedBox(height: 14),

              // Date
              _label('Date'),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDec(),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Text(DateFormat('EEEE, MMM d, yyyy').format(_date),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Times
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Start Time'),
                        InkWell(
                          onTap: () => _pickTime(true),
                          child: InputDecorator(
                            decoration: _inputDec(),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text(_startTime,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('End Time'),
                        InkWell(
                          onTap: () => _pickTime(false),
                          child: InputDecorator(
                            decoration: _inputDec(),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 8),
                                Text(_endTime,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Role
              _label('Role'),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: _inputDec(),
                items: _roles.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(_roleLabel(r)),
                    )).toList(),
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 14),

              // Status (only when editing)
              if (isEdit) ...[
                _label('Status'),
                DropdownButtonFormField<ShiftStatus>(
                  initialValue: _status,
                  decoration: _inputDec(),
                  items: ShiftStatus.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_statusLabel(s)),
                      )).toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 14),
              ],

              // Notes
              _label('Notes (optional)'),
              TextField(
                controller: _notesCtrl,
                decoration: _inputDec(hint: 'Any special instructions…'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedStaff != null ? _submit : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: _kAccent),
                    child: Text(isEdit ? 'Save Changes' : 'Add Shift'),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569))),
      );

  static InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kAccent, width: 1.5)),
      );

  static String _roleLabel(String role) => role
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');

  static String _statusLabel(ShiftStatus s) {
    return switch (s) {
      ShiftStatus.scheduled  => 'Scheduled',
      ShiftStatus.completed  => 'Completed',
      ShiftStatus.cancelled  => 'Cancelled',
    };
  }
}
