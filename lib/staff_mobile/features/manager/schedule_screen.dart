import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/staff_permission.dart';
import '../../../domain/entities/staff_shift.dart';
import '../../../providers/service_providers.dart';
import '../../../services/shift_service.dart';
import '../../data/connectivity.dart';
import '../../data/manager_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

const _uuid = Uuid();

typedef _RotaView = ({
  List<StaffShift> shifts,
  List<PropertyStaffMember> team,
});

final _rotaProvider =
    FutureProvider.autoDispose.family<_RotaView, int>((ref, weekOffset) async {
  final propertyId = ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));
  if (propertyId == null) {
    return (shifts: <StaffShift>[], team: <PropertyStaffMember>[]);
  }

  final anchor =
      DateTime.now().add(Duration(days: 7 * weekOffset));
  final results = await (
    ref.watch(managerRepositoryProvider).shiftsForWeek(anchor),
    ref.watch(staffServiceProvider).getPropertyStaff(propertyId),
  ).wait;

  return (shifts: results.$1, team: results.$2);
});

/// Next week's rota.
///
/// The roadmap warns this one is "genuinely hard to fit on a phone — consider
/// tablet-only", and that is right about the *grid*: seven columns by a dozen
/// staff is unreadable at 390px. So the phone layout is not a grid. It is one
/// day at a time with a day strip across the top, which is how a rota is
/// actually edited anyway — you sit down to fill Tuesday, not to admire the
/// week. A genuine week grid appears only when there is width for it.
///
/// Copy-previous-week is the feature that makes the whole thing bearable, since
/// most weeks are last week with two changes.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _weekOffset = 0;
  int _selectedDay = 0;
  bool _busy = false;

  static final _dayShort = DateFormat('EEE');
  static final _dayNum = DateFormat('d');
  static final _weekLabel = DateFormat('d MMM');

  DateTime get _weekStart =>
      ShiftService.weekStart(DateTime.now().add(Duration(days: 7 * _weekOffset)));

  List<DateTime> get _days =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_rotaProvider(_weekOffset));
    final session = ref.watch(staffSessionProvider).valueOrNull;
    final mayEdit = session?.isManager ?? false;
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota'),
        actions: [
          if (mayEdit)
            IconButton(
              tooltip: 'Copy last week',
              icon: const Icon(Icons.copy_all_rounded),
              onPressed: _busy ? null : _copyLastWeek,
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          _WeekBar(
            weekStart: _weekStart,
            label: _weekLabel,
            onPrevious: () => setState(() => _weekOffset--),
            onNext: () => setState(() => _weekOffset++),
            onToday: _weekOffset == 0
                ? null
                : () => setState(() => _weekOffset = 0),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Could not load the rota.\n\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (view) => isWide
                  ? _weekGrid(view, mayEdit)
                  : _dayView(view, mayEdit),
            ),
          ),
        ],
      ),
      floatingActionButton: mayEdit && !isWide
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _addShift(_days[_selectedDay]),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add shift'),
            )
          : null,
    );
  }

  // ─── Phone: one day at a time ─────────────────────────────────────────────

  Widget _dayView(_RotaView view, bool mayEdit) {
    final days = _days;
    final forDay = view.shifts
        .where((s) => _sameDay(s.shiftDate, days[_selectedDay]))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final count =
                  view.shifts.where((s) => _sameDay(s.shiftDate, days[i])).length;
              return _DayChip(
                day: days[i],
                shortFormat: _dayShort,
                numFormat: _dayNum,
                shiftCount: count,
                selected: i == _selectedDay,
                isToday: _sameDay(days[i], DateTime.now()),
                onTap: () => setState(() => _selectedDay = i),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: forDay.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      mayEdit
                          ? 'Nobody on this day yet.'
                          : 'Nobody scheduled on this day.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: forDay.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ShiftCard(
                    shift: forDay[i],
                    editable: mayEdit,
                    onDelete: () => _deleteShift(forDay[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Tablet: the actual week grid ─────────────────────────────────────────

  Widget _weekGrid(_RotaView view, bool mayEdit) {
    final days = _days;
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${_dayShort.format(days[i])} ${_dayNum.format(days[i])}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _sameDay(days[i], DateTime.now())
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final shift in view.shifts
                        .where((s) => _sameDay(s.shiftDate, days[i]))
                        .toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime)))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _ShiftCard(
                          shift: shift,
                          editable: mayEdit,
                          compact: true,
                          onDelete: () => _deleteShift(shift),
                        ),
                      ),
                    if (mayEdit)
                      TextButton(
                        onPressed:
                            _busy ? null : () => _addShift(days[i]),
                        child: const Text('+'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _addShift(DateTime day) async {
    final view = ref.read(_rotaProvider(_weekOffset)).valueOrNull;
    if (view == null || view.team.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Nobody is assigned to this property yet.'),
        ));
      return;
    }

    final draft = await showModalBottomSheet<_ShiftDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShiftSheet(day: day, team: view.team),
    );
    if (draft == null || !mounted) return;

    final propertyId =
        ref.read(staffSessionProvider).valueOrNull?.activeProperty?.id;
    if (propertyId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(managerRepositoryProvider).addShift(StaffShift(
            id: _uuid.v4(),
            hotelId: propertyId,
            staffUserId: draft.member.userId,
            staffName: draft.member.fullName,
            shiftDate: day,
            startTime: draft.start,
            endTime: draft.end,
            role: draft.role,
            notes: '',
            status: ShiftStatus.scheduled,
            createdAt: DateTime.now(),
          ));
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(_rotaProvider(_weekOffset));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Adding the shift',
      );
    }
  }

  Future<void> _deleteShift(StaffShift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this shift?'),
        content: Text(
          '${shift.staffName} · ${shift.startTime}–${shift.endTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(managerRepositoryProvider).deleteShift(shift.id);
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(_rotaProvider(_weekOffset));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Removing the shift',
      );
    }
  }

  Future<void> _copyLastWeek() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy last week?'),
        content: const Text(
          'Every shift from the previous week is copied onto this one. '
          'Anything already scheduled here is left alone, so running this '
          'twice will not double-book anyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final copied = await ref.read(managerRepositoryProvider).copyWeek(
            fromWeek: _weekStart.subtract(const Duration(days: 7)),
            toWeek: _weekStart,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(_rotaProvider(_weekOffset));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(copied == 0
              ? 'Nothing to copy — last week was empty, or everything is '
                  'already scheduled.'
              : 'Copied $copied shift${copied == 1 ? '' : 's'}'),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: ref.read(isOnlineProvider),
        action: 'Copying last week',
      );
    }
  }
}

class _WeekBar extends StatelessWidget {
  final DateTime weekStart;
  final DateFormat label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  const _WeekBar({
    required this.weekStart,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${label.format(weekStart)} – ${label.format(end)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (onToday != null)
            TextButton(onPressed: onToday, child: const Text('This week')),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final DateFormat shortFormat;
  final DateFormat numFormat;
  final int shiftCount;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.shortFormat,
    required this.numFormat,
    required this.shiftCount,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !selected
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(shortFormat.format(day),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  )),
              Text(numFormat.format(day),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimaryContainer : null,
                  )),
              // A dot rather than a number: the count matters less than whether
              // the day has anyone on it at all.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shiftCount == 0
                      ? Colors.transparent
                      : (selected ? scheme.onPrimaryContainer : scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final StaffShift shift;
  final bool editable;
  final bool compact;
  final VoidCallback onDelete;

  const _ShiftCard({
    required this.shift,
    required this.editable,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 8 : 14, 10, compact ? 4 : 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shift.staffName.trim().isEmpty
                        ? 'Unnamed'
                        : shift.staffName,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${shift.startTime}–${shift.endTime}'
                    '${shift.role.isEmpty ? '' : ' · ${shift.role}'}',
                    style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (editable)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
                icon: Icon(Icons.close_rounded,
                    size: compact ? 16 : 20, color: scheme.onSurfaceVariant),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftDraft {
  final PropertyStaffMember member;
  final String start;
  final String end;
  final String role;
  const _ShiftDraft({
    required this.member,
    required this.start,
    required this.end,
    required this.role,
  });
}

/// Who, and when.
class _ShiftSheet extends StatefulWidget {
  final DateTime day;
  final List<PropertyStaffMember> team;

  const _ShiftSheet({required this.day, required this.team});

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  late PropertyStaffMember _member = widget.team.first;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _role = TextEditingController();

  @override
  void dispose() {
    _role.dispose();
    super.dispose();
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(DateFormat('EEEE d MMMM').format(widget.day),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _member.userId,
                decoration: const InputDecoration(
                  labelText: 'Who',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: [
                  for (final m in widget.team)
                    DropdownMenuItem(
                      value: m.userId,
                      child: Text(m.fullName.trim().isEmpty
                          ? m.email
                          : m.fullName),
                    ),
                ],
                onChanged: (id) => setState(() => _member =
                    widget.team.firstWhere((m) => m.userId == id)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Start',
                      value: _start,
                      onPick: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _start);
                        if (picked != null) setState(() => _start = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'End',
                      value: _end,
                      onPick: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _end);
                        if (picked != null) setState(() => _end = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _role,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Role (optional)',
                  hintText: 'e.g. Bar, Kitchen',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_ShiftDraft(
                  member: _member,
                  start: _hhmm(_start),
                  end: _hhmm(_end),
                  role: _role.text.trim(),
                )),
                child: const Text('Add shift'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onPick;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_rounded, size: 18),
        ),
        child: Text(value.format(context),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
