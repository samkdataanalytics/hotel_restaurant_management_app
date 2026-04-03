import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/guest.dart';
import '../../models/room.dart';
import '../../services/booking_service.dart';

// ─── Colour palette ────────────────────────────────────────────────────────────
class _C {
  static const bg      = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const card    = Color(0xFF263245);
  static const gold    = Color(0xFFD4A853);
  static const text    = Colors.white;
  static const subtext = Color(0xFF94A3B8);
  static const divider = Color(0xFF334155);
  static const error   = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
}

// ─── Steps ────────────────────────────────────────────────────────────────────
enum _Step { summary, personal, preferences, agreement }

class GuestCheckinScreen extends StatefulWidget {
  /// Booking reference passed via ?ref= query param.
  /// If empty, the screen shows a manual lookup field.
  final String bookingRef;

  const GuestCheckinScreen({super.key, required this.bookingRef});

  @override
  State<GuestCheckinScreen> createState() => _GuestCheckinScreenState();
}

class _GuestCheckinScreenState extends State<GuestCheckinScreen> {
  final _bookingService = BookingService();
  final _dateFmt = DateFormat('EEE, MMM d yyyy');
  final _refCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _submitting = false;
  String? _lookupError;
  bool _alreadySubmitted = false;
  bool _done = false;

  Booking? _booking;
  Guest?   _guest;
  Room?    _room;

  _Step _step = _Step.summary;

  // ── Personal info ──────────────────────────────────────────────────────────
  final _nameCtrl       = TextEditingController();
  final _passportCtrl   = TextEditingController();
  final _nationalityCtrl= TextEditingController();
  final _dobCtrl        = TextEditingController();
  final _whatsAppCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  DateTime? _dob;

  // ── Preferences ────────────────────────────────────────────────────────────
  String _bikeRental       = 'No';
  String _airportTransfer  = 'No';
  String _surfingLessons   = 'No';
  String _yogaLessons      = 'No';
  String _whaleWatching    = 'No';
  String _safaris          = 'None';
  final _requestsCtrl = TextEditingController();

  // ── Agreement ──────────────────────────────────────────────────────────────
  bool _agreedToTerms = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.bookingRef.isNotEmpty) {
      _lookupBooking(widget.bookingRef);
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _nameCtrl.dispose();
    _passportCtrl.dispose();
    _nationalityCtrl.dispose();
    _dobCtrl.dispose();
    _whatsAppCtrl.dispose();
    _emailCtrl.dispose();
    _requestsCtrl.dispose();
    super.dispose();
  }

  // ── Booking lookup ─────────────────────────────────────────────────────────
  Future<void> _lookupBooking(String ref) async {
    setState(() { _loading = true; _lookupError = null; });
    final data = await _bookingService.lookupBooking(ref.trim().toUpperCase());
    if (!mounted) return;

    if (data == null) {
      setState(() { _lookupError = 'No booking found for "$ref". Please check and try again.'; _loading = false; });
      return;
    }

    final booking = data['booking'] as Booking;
    final guest   = data['guest']   as Guest;
    final room    = data['room']    as Room?;

    if (booking.isGuestFormSubmitted) {
      setState(() { _alreadySubmitted = true; _booking = booking; _guest = guest; _room = room; _loading = false; });
      return;
    }

    // Pre-fill personal form
    _nameCtrl.text        = guest.fullName;
    _emailCtrl.text       = guest.email;
    _passportCtrl.text    = guest.passportOrNic ?? guest.idNumber;
    _nationalityCtrl.text = guest.nationality;
    _whatsAppCtrl.text    = guest.whatsApp ?? guest.phone;
    if (guest.dateOfBirth != null) {
      _dob = guest.dateOfBirth;
      _dobCtrl.text = _dateFmt.format(_dob!);
    }
    // Pre-fill saved preferences
    if (booking.guestPreferences != null) {
      final p = booking.guestPreferences!;
      _bikeRental      = p['bikeRental']      as String? ?? 'No';
      _airportTransfer = p['airportTransfer']  as String? ?? 'No';
      _surfingLessons  = p['surfingLessons']   as String? ?? 'No';
      _yogaLessons     = p['yogaLessons']      as String? ?? 'No';
      _whaleWatching   = p['whaleWatching']    as String? ?? 'No';
      _safaris         = p['safaris']          as String? ?? 'None';
      _requestsCtrl.text = p['specialRequests'] as String? ?? '';
    }

    setState(() { _booking = booking; _guest = guest; _room = room; _loading = false; });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_agreedToTerms) return;
    setState(() => _submitting = true);

    final updatedGuest = _guest!.copyWith(
      fullName:      _nameCtrl.text.trim(),
      email:         _emailCtrl.text.trim(),
      passportOrNic: _passportCtrl.text.trim(),
      nationality:   _nationalityCtrl.text.trim(),
      whatsApp:      _whatsAppCtrl.text.trim(),
      dateOfBirth:   _dob,
    );
    await _bookingService.updateGuest(updatedGuest);

    final prefs = {
      'bikeRental':      _bikeRental,
      'airportTransfer': _airportTransfer,
      'surfingLessons':  _surfingLessons,
      'yogaLessons':     _yogaLessons,
      'whaleWatching':   _whaleWatching,
      'safaris':         _safaris,
      'specialRequests': _requestsCtrl.text.trim(),
    };

    final updatedBooking = _booking!.copyWith(
      isGuestFormSubmitted: true,
      guestPreferences: prefs,
      specialRequests: _requestsCtrl.text.trim().isNotEmpty
          ? _requestsCtrl.text.trim()
          : _booking!.specialRequests,
    );
    await _bookingService.updateBooking(updatedBooking);

    if (mounted) setState(() { _done = true; _submitting = false; });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _next() {
    final steps = _Step.values;
    final idx = steps.indexOf(_step);
    if (idx < steps.length - 1) setState(() => _step = steps[idx + 1]);
  }

  void _back() {
    final steps = _Step.values;
    final idx = steps.indexOf(_step);
    if (idx > 0) setState(() => _step = steps[idx - 1]);
  }

  bool _canProceedPersonal() =>
      _nameCtrl.text.isNotEmpty &&
      _passportCtrl.text.isNotEmpty &&
      _emailCtrl.text.isNotEmpty;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingView();
    if (_done) return _doneView();
    if (_alreadySubmitted) return _alreadySubmittedView();
    if (_booking == null) return _lookupView();
    return _wizardView();
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _loadingView() => Scaffold(
    backgroundColor: _C.bg,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/images/hotrest_logo.png', width: 80, height: 80),
      const SizedBox(height: 24),
      const CircularProgressIndicator(color: _C.gold),
      const SizedBox(height: 16),
      const Text('Looking up your booking…', style: TextStyle(color: _C.subtext, fontSize: 14)),
    ])),
  );

  // ── Manual lookup ──────────────────────────────────────────────────────────
  Widget _lookupView() => Scaffold(
    backgroundColor: _C.bg,
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/hotrest_logo.png', width: 80, height: 80),
        const SizedBox(height: 24),
        const Text('Online Check-In', style: TextStyle(color: _C.text, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Enter your booking reference to get started.',
            style: TextStyle(color: _C.subtext, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        _darkField(
          controller: _refCtrl,
          label: 'Booking Reference',
          hint: 'e.g. BK-0042',
          prefixIcon: Icons.confirmation_number_outlined,
          onSubmitted: (_) => _lookupBooking(_refCtrl.text),
        ),
        if (_lookupError != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.error_outline, color: _C.error, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(_lookupError!, style: const TextStyle(color: _C.error, fontSize: 13))),
          ]),
        ],
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () => _lookupBooking(_refCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.gold, foregroundColor: _C.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Find My Booking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    ))),
  );

  // ── Already submitted ──────────────────────────────────────────────────────
  Widget _alreadySubmittedView() => Scaffold(
    backgroundColor: _C.bg,
    body: SafeArea(child: _confirmationCard(alreadyDone: true)),
  );

  // ── Done ───────────────────────────────────────────────────────────────────
  Widget _doneView() => Scaffold(
    backgroundColor: _C.bg,
    body: SafeArea(child: _confirmationCard(alreadyDone: false)),
  );

  Widget _confirmationCard({required bool alreadyDone}) {
    final b = _booking!;
    final g = _guest;
    final r = _room;
    final nights = b.checkOutDate.difference(b.checkInDate).inDays;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const SizedBox(height: 16),
        Image.asset('assets/images/hotrest_logo.png', width: 72, height: 72),
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: _C.success.withOpacity(0.15), shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: _C.success, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          alreadyDone ? 'Already Checked In' : 'Check-In Complete!',
          style: const TextStyle(color: _C.text, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          alreadyDone
              ? 'Your details are already on file. See you soon!'
              : 'Your information has been received. We look forward to welcoming you!',
          style: const TextStyle(color: _C.subtext, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Booking card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.gold.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.gold.withOpacity(0.3)),
                ),
                child: Text(b.bookingRef,
                    style: const TextStyle(color: _C.gold, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 16),
            if (g != null) _confirmRow(Icons.person_outline_rounded, 'Guest', g.fullName),
            if (r != null) ...[
              const SizedBox(height: 12),
              _confirmRow(Icons.meeting_room_outlined, 'Room',
                  'Room ${r.roomNumber} · ${r.typeLabel} · Floor ${r.floor}'),
            ],
            const SizedBox(height: 12),
            _confirmRow(Icons.login_rounded, 'Check-In', _dateFmt.format(b.checkInDate)),
            const SizedBox(height: 12),
            _confirmRow(Icons.logout_rounded, 'Check-Out', _dateFmt.format(b.checkOutDate)),
            const SizedBox(height: 12),
            _confirmRow(Icons.nights_stay_outlined, 'Duration', '$nights night${nights != 1 ? 's' : ''}'),
            const SizedBox(height: 12),
            _confirmRow(Icons.group_outlined, 'Guests', b.numberOfGuests.toString()),
            if (b.totalAmount > 0) ...[
              const SizedBox(height: 12),
              _confirmRow(Icons.receipt_outlined, 'Total',
                  NumberFormat.currency(symbol: '', decimalDigits: 2).format(b.totalAmount)),
            ],
          ]),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.divider),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: _C.subtext, size: 18),
            SizedBox(width: 12),
            Expanded(child: Text(
              'Please present this reference at the front desk upon arrival. Our team will have everything ready for you.',
              style: TextStyle(color: _C.subtext, fontSize: 12),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: _C.subtext, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _C.subtext, fontSize: 11)),
        Text(value, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600, fontSize: 14)),
      ])),
    ],
  );

  // ── Wizard ─────────────────────────────────────────────────────────────────
  Widget _wizardView() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(children: [
        _wizardHeader(),
        _stepProgress(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          child: _stepContent(),
        )),
      ]),
      bottomNavigationBar: _wizardFooter(),
    );
  }

  Widget _wizardHeader() => Container(
    decoration: const BoxDecoration(
      color: _C.surface,
      border: Border(bottom: BorderSide(color: _C.divider)),
    ),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Image.asset('assets/images/hotrest_logo.png', width: 36, height: 36),
        const SizedBox(width: 12),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Online Check-In', style: TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Complete your pre-arrival registration', style: TextStyle(color: _C.subtext, fontSize: 11)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.gold.withOpacity(0.3)),
          ),
          child: Text(_booking!.bookingRef,
              style: const TextStyle(color: _C.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    )),
  );

  Widget _stepProgress() {
    final steps = _Step.values;
    final labels = ['Summary', 'Details', 'Preferences', 'Confirm'];
    return Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done    = steps.indexOf(_step) > i;
          final current = steps[i] == _step;
          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: done ? _C.success : current ? _C.gold : _C.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: done ? _C.success : current ? _C.gold : _C.divider),
                ),
                child: Center(child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : Text('${i + 1}', style: TextStyle(
                        color: current ? _C.bg : _C.subtext,
                        fontSize: 12, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(
                  color: current ? _C.gold : done ? _C.success : _C.subtext,
                  fontSize: 10, fontWeight: current ? FontWeight.w700 : FontWeight.w400)),
            ])),
            if (i < steps.length - 1)
              Expanded(child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 20),
                color: done ? _C.success : _C.divider,
              )),
          ]));
        }),
      ),
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      _Step.summary     => _summaryStep(),
      _Step.personal    => _personalStep(),
      _Step.preferences => _preferencesStep(),
      _Step.agreement   => _agreementStep(),
    };
  }

  // Step 1 — Booking summary ──────────────────────────────────────────────────
  Widget _summaryStep() {
    final b = _booking!;
    final r = _room;
    final nights = b.checkOutDate.difference(b.checkInDate).inDays;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      _sectionTitle('Your Booking', Icons.hotel_rounded),
      const SizedBox(height: 16),

      // Room card
      if (r != null)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.gold.withOpacity(0.2), _C.gold.withOpacity(0.05)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.gold.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _C.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.meeting_room_outlined, color: _C.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Room ${r.roomNumber}',
                    style: const TextStyle(color: _C.text, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('${r.typeLabel} · Floor ${r.floor}',
                    style: const TextStyle(color: _C.subtext, fontSize: 13)),
              ])),
            ]),
            const SizedBox(height: 16),
            const Divider(color: _C.divider, height: 1),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _summaryTile(Icons.login_rounded, 'Check-In', _dateFmt.format(b.checkInDate))),
              Container(width: 1, height: 40, color: _C.divider),
              Expanded(child: _summaryTile(Icons.logout_rounded, 'Check-Out', _dateFmt.format(b.checkOutDate))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _summaryTile(Icons.nights_stay_outlined, 'Nights', nights.toString())),
              Container(width: 1, height: 40, color: _C.divider),
              Expanded(child: _summaryTile(Icons.group_outlined, 'Guests', b.numberOfGuests.toString())),
            ]),
          ]),
        ),

      const SizedBox(height: 16),

      // Details card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider),
        ),
        child: Column(children: [
          _detailRow('Booking Ref', b.bookingRef),
          const Divider(color: _C.divider, height: 20),
          _detailRow('Status', b.statusLabel),
          if (b.totalAmount > 0) ...[
            const Divider(color: _C.divider, height: 20),
            _detailRow('Total Amount',
                NumberFormat.currency(symbol: '', decimalDigits: 2).format(b.totalAmount)),
          ],
          if (b.specialRequests.isNotEmpty) ...[
            const Divider(color: _C.divider, height: 20),
            _detailRow('Special Requests', b.specialRequests),
          ],
        ]),
      ),

      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.gold.withOpacity(0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: _C.gold, size: 16),
          SizedBox(width: 10),
          Expanded(child: Text(
            'Please complete your online check-in at least 2 hours before arrival to ensure a smooth welcome.',
            style: TextStyle(color: _C.gold, fontSize: 12),
          )),
        ]),
      ),
    ]);
  }

  Widget _summaryTile(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(children: [
      Icon(icon, color: _C.subtext, size: 16),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: _C.subtext, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w700, fontSize: 13)),
    ]),
  );

  // Step 2 — Personal details ─────────────────────────────────────────────────
  Widget _personalStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 24),
    _sectionTitle('Personal Information', Icons.person_outline_rounded),
    const SizedBox(height: 6),
    const Text('Please verify your details. Fields marked * are required.',
        style: TextStyle(color: _C.subtext, fontSize: 12)),
    const SizedBox(height: 20),
    _darkField(controller: _nameCtrl, label: 'Full Name *',
        hint: 'As on your ID', prefixIcon: Icons.badge_outlined,
        onChanged: (_) => setState(() {})),
    const SizedBox(height: 14),
    _darkField(controller: _passportCtrl, label: 'Passport / NIC *',
        hint: 'Document number', prefixIcon: Icons.article_outlined,
        onChanged: (_) => setState(() {})),
    const SizedBox(height: 14),
    _darkField(controller: _nationalityCtrl, label: 'Nationality',
        hint: 'e.g. Sri Lankan', prefixIcon: Icons.flag_outlined),
    const SizedBox(height: 14),
    // Date of birth
    GestureDetector(
      onTap: _pickDob,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _C.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.divider),
        ),
        child: Row(children: [
          const Icon(Icons.cake_outlined, color: _C.subtext, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Date of Birth', style: TextStyle(color: _C.subtext, fontSize: 11)),
            const SizedBox(height: 2),
            Text(_dob == null ? 'Select date' : _dateFmt.format(_dob!),
                style: TextStyle(color: _dob == null ? _C.subtext : _C.text, fontSize: 14)),
          ])),
          const Icon(Icons.calendar_today_rounded, color: _C.subtext, size: 16),
        ]),
      ),
    ),
    const SizedBox(height: 14),
    _darkField(controller: _whatsAppCtrl, label: 'WhatsApp Number',
        hint: '+94 7X XXX XXXX', prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    _darkField(controller: _emailCtrl, label: 'Email Address *',
        hint: 'you@example.com', prefixIcon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) => setState(() {})),
  ]);

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _C.gold, onPrimary: _C.bg),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _dob = picked; _dobCtrl.text = _dateFmt.format(picked); });
    }
  }

  // Step 3 — Preferences ──────────────────────────────────────────────────────
  Widget _preferencesStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 24),
    _sectionTitle('Stay Preferences', Icons.tune_rounded),
    const SizedBox(height: 6),
    const Text('Help us make your stay more enjoyable. All optional.',
        style: TextStyle(color: _C.subtext, fontSize: 12)),
    const SizedBox(height: 20),
    _prefDropdown('Bike / Scooter Rental', _bikeRental, ['Yes', 'No', 'Maybe Later'],
        (v) => setState(() => _bikeRental = v!)),
    _prefDropdown('Airport Transfer', _airportTransfer,
        ['Yes - Pickup', 'Yes - Drop', 'Yes - Both', 'No', 'Maybe Later'],
        (v) => setState(() => _airportTransfer = v!)),
    _prefDropdown('Surfing Lessons', _surfingLessons,
        ['Beginner', 'Intermediate', 'No', 'Maybe Later'],
        (v) => setState(() => _surfingLessons = v!)),
    _prefDropdown('Yoga Sessions', _yogaLessons, ['Yes', 'No', 'Maybe Later'],
        (v) => setState(() => _yogaLessons = v!)),
    _prefDropdown('Whale Watching', _whaleWatching, ['Yes', 'No', 'Maybe Later'],
        (v) => setState(() => _whaleWatching = v!)),
    _prefDropdown('Safari', _safaris, ['Udawalawa', 'Yala', 'Both', 'None', 'Maybe Later'],
        (v) => setState(() => _safaris = v!)),
    const SizedBox(height: 14),
    Container(
      decoration: BoxDecoration(
        color: _C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: TextField(
        controller: _requestsCtrl,
        maxLines: 4,
        style: const TextStyle(color: _C.text, fontSize: 14),
        decoration: const InputDecoration(
          labelText: 'Special Requests',
          labelStyle: TextStyle(color: _C.subtext),
          hintText: 'Dietary needs, room preferences, celebrations…',
          hintStyle: TextStyle(color: _C.subtext, fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    ),
  ]);

  Widget _prefDropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: _C.surface,
          style: const TextStyle(color: _C.text, fontSize: 14),
          hint: Text(label, style: const TextStyle(color: _C.subtext)),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          selectedItemBuilder: (_) => options.map((e) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: _C.subtext, fontSize: 10)),
              Text(e, style: const TextStyle(color: _C.text, fontSize: 14)),
            ],
          )).toList(),
        ),
      ),
    );
  }

  // Step 4 — Agreement ────────────────────────────────────────────────────────
  Widget _agreementStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 24),
    _sectionTitle('Review & Confirm', Icons.task_alt_rounded),
    const SizedBox(height: 16),

    // Summary of entered info
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider),
      ),
      child: Column(children: [
        _reviewRow('Name',        _nameCtrl.text),
        const Divider(color: _C.divider, height: 16),
        _reviewRow('Passport/NIC', _passportCtrl.text),
        const Divider(color: _C.divider, height: 16),
        _reviewRow('Nationality',  _nationalityCtrl.text.isNotEmpty ? _nationalityCtrl.text : '–'),
        const Divider(color: _C.divider, height: 16),
        _reviewRow('Date of Birth', _dob != null ? _dateFmt.format(_dob!) : '–'),
        const Divider(color: _C.divider, height: 16),
        _reviewRow('WhatsApp',     _whatsAppCtrl.text.isNotEmpty ? _whatsAppCtrl.text : '–'),
        const Divider(color: _C.divider, height: 16),
        _reviewRow('Email',        _emailCtrl.text),
      ]),
    ),
    const SizedBox(height: 20),

    // Policy agreement
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _agreedToTerms ? _C.gold.withOpacity(0.4) : _C.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
          activeColor: _C.gold,
          checkColor: _C.bg,
          side: BorderSide(color: _agreedToTerms ? _C.gold : _C.subtext),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'I confirm that all the information provided is accurate and I agree to the hotel\'s check-in policies, cancellation terms, and house rules.',
            style: TextStyle(color: _C.subtext, fontSize: 13, height: 1.5),
          ),
        )),
      ]),
    ),

    if (!_agreedToTerms) ...[
      const SizedBox(height: 8),
      const Row(children: [
        SizedBox(width: 8),
        Icon(Icons.info_outline_rounded, color: _C.subtext, size: 14),
        SizedBox(width: 6),
        Text('Please accept the terms to complete check-in.',
            style: TextStyle(color: _C.subtext, fontSize: 12)),
      ]),
    ],
  ]);

  Widget _reviewRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
      Flexible(child: Text(value,
          style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600, fontSize: 13),
          textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
    ],
  );

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _wizardFooter() {
    final isFirst = _step == _Step.values.first;
    final isLast  = _step == _Step.values.last;
    final canNext = _step == _Step.personal ? _canProceedPersonal() : true;

    return Container(
      color: _C.surface,
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: Row(children: [
        if (!isFirst)
          Expanded(child: OutlinedButton(
            onPressed: _back,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.divider),
              foregroundColor: _C.subtext,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Back'),
          )),
        if (!isFirst) const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: isLast
              ? (_agreedToTerms && !_submitting ? _submit : null)
              : (canNext ? _next : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.gold,
            foregroundColor: _C.bg,
            disabledBackgroundColor: _C.gold.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(0, 48),
          ),
          child: _submitting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _C.bg, strokeWidth: 2))
              : Text(
                  isLast ? 'Complete Check-In' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
        )),
      ]),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: _C.gold, size: 20),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w700)),
  ]);

  Widget _detailRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: _C.subtext, fontSize: 13)),
      Flexible(child: Text(value,
          style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600, fontSize: 14),
          textAlign: TextAlign.end)),
    ],
  );

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: _C.text, fontSize: 14),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _C.subtext, fontSize: 12),
          hintText: hint,
          hintStyle: const TextStyle(color: _C.subtext, fontSize: 13),
          prefixIcon: Icon(prefixIcon, color: _C.subtext, size: 20),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
