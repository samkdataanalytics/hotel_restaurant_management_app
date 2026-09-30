import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/staff_shift.dart';
import '../../../providers/app_auth_provider.dart';
import '../../data/connectivity.dart';
import '../../data/manager_repository.dart';
import '../../session/staff_session.dart';
import '../../widgets/offline_banner.dart';

typedef _ShiftView = ({
  TimeRecord? active,
  List<StaffShift> shifts,
  List<TimeRecord> recent,
});

final _myShiftProvider = FutureProvider.autoDispose<_ShiftView>((ref) async {
  ref.watch(
      staffSessionProvider.select((s) => s.valueOrNull?.activeProperty?.id));

  final userId = ref.watch(authProvider).valueOrNull?.userId;
  final repo = ref.watch(managerRepositoryProvider);
  if (userId == null) {
    return (active: null, shifts: <StaffShift>[], recent: <TimeRecord>[]);
  }

  final results = await (
    repo.activeTimeRecord(),
    repo.myShiftsThisWeek(userId),
    repo.myRecentTimeRecords(userId),
  ).wait;

  return (active: results.$1, shifts: results.$2, recent: results.$3);
});

/// Clock in, clock out, and see the week ahead.
///
/// The one screen every staff member has a daily reason to open, which is why
/// the roadmap calls it the standout — the backend was already complete, so
/// this is nearly all UI.
///
/// Verified clock-in (location or a premises QR) is NOT implemented. The
/// roadmap leaves the method open, and the two options differ in what they cost
/// the user: location adds a permission prompt and a privacy conversation, a
/// premises QR adds neither but needs a code printed and stuck somewhere. That
/// is a decision about how much you trust staff, not a technical one.
class MyShiftScreen extends ConsumerStatefulWidget {
  const MyShiftScreen({super.key});

  @override
  ConsumerState<MyShiftScreen> createState() => _MyShiftScreenState();
}

class _MyShiftScreenState extends ConsumerState<MyShiftScreen> {
  Timer? _ticker;
  bool _busy = false;

  static final _dayFormat = DateFormat('EEE d MMM');
  static final _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    // The elapsed counter is the only thing on screen with no server event
    // behind it.
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_myShiftProvider);

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(_myShiftProvider.future),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Could not load your shifts.\n\n$e',
                        textAlign: TextAlign.center),
                  ),
                ),
              ]),
              data: (view) => _body(view),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(_ShiftView view) {
    final scheme = Theme.of(context).colorScheme;
    final onShift = view.active != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Card(
          color: onShift ? scheme.primaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              children: [
                Text(
                  onShift ? 'On shift' : 'Not clocked in',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: onShift ? scheme.onPrimaryContainer : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  onShift
                      ? _elapsed(view.active!.clockIn)
                      : 'Start your shift when you arrive',
                  style: TextStyle(
                    fontSize: onShift ? 34 : 14,
                    fontWeight: onShift ? FontWeight.w800 : FontWeight.w400,
                    height: 1.1,
                    color: onShift
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (onShift) ...[
                  const SizedBox(height: 4),
                  Text(
                    'since ${_timeFormat.format(view.active!.clockIn)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => onShift ? _clockOut(view.active!) : _clockIn(),
                    style: onShift
                        ? FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          )
                        : null,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Icon(onShift
                            ? Icons.logout_rounded
                            : Icons.login_rounded),
                    label: Text(_busy
                        ? 'Saving'
                        : onShift
                            ? 'Clock out'
                            : 'Clock in'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),
        Text('This week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (view.shifts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No shifts scheduled for you this week.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final shift in view.shifts)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  shift.status == ShiftStatus.cancelled
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  color: shift.status == ShiftStatus.cancelled
                      ? scheme.error
                      : scheme.primary,
                ),
                title: Text(_dayFormat.format(shift.shiftDate)),
                subtitle: Text(
                  '${shift.startTime} – ${shift.endTime}'
                  '${shift.role.isEmpty ? '' : ' · ${shift.role}'}',
                ),
                trailing: shift.status == ShiftStatus.cancelled
                    ? Text('Cancelled',
                        style: TextStyle(color: scheme.error, fontSize: 12.5))
                    : Text(shift.durationLabel,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12.5)),
              ),
            ),

        const SizedBox(height: 22),
        Text('Recent hours', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Your own clock-ins over the past two weeks.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (view.recent.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Nothing recorded yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          )
        else
          for (final record in view.recent)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(_dayFormat.format(record.clockIn)),
                subtitle: Text(
                  record.clockOut == null
                      ? 'From ${_timeFormat.format(record.clockIn)} — still open'
                      : '${_timeFormat.format(record.clockIn)} – '
                          '${_timeFormat.format(record.clockOut!)}',
                ),
                trailing: Text(
                  record.clockOut == null ? '—' : _durationLabel(record),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
      ],
    );
  }

  static String _elapsed(DateTime since) {
    final d = DateTime.now().difference(since);
    if (d.isNegative) return '0h 00m';
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  static String _durationLabel(TimeRecord record) {
    final end = record.clockOut;
    if (end == null) return '—';
    final d = end.difference(record.clockIn);
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }

  Future<void> _clockIn() async {
    setState(() => _busy = true);
    final isOnline = ref.read(isOnlineProvider);
    final name = ref.read(authProvider).valueOrNull?.email ?? '';

    try {
      await ref.read(managerRepositoryProvider).clockIn(staffName: name);
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(_myShiftProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Clocking in',
      );
    }
  }

  Future<void> _clockOut(TimeRecord record) async {
    // Clocking out is what the hours are paid on, and there is no undo in the
    // service, so it gets a confirmation with the elapsed time on it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clock out?'),
        content: Text(
          'You have been on shift ${_elapsed(record.clockIn)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay on'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clock out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final isOnline = ref.read(isOnlineProvider);

    try {
      await ref.read(managerRepositoryProvider).clockOut(record.id);
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(_myShiftProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showWriteFailure(
        context,
        error: e,
        isOnline: isOnline,
        action: 'Clocking out',
      );
    }
  }
}
