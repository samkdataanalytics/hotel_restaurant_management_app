import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';
import '../services/booking_service.dart';

class CheckinConfirmScreen extends StatefulWidget {
  const CheckinConfirmScreen({super.key});

  @override
  State<CheckinConfirmScreen> createState() => _CheckinConfirmScreenState();
}

class _CheckinConfirmScreenState extends State<CheckinConfirmScreen> {
  final _bookingService = BookingService();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  bool _isProcessing = false;

  Booking? _booking;
  Guest? _guest;
  Room? _room;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booking == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _booking = args['booking'] as Booking;
        _guest = args['guest'] as Guest;
        _room = args['room'] as Room?;
      }
    }
  }

  Future<void> _confirmCheckIn() async {
    if (_booking == null || _guest == null) return;

    setState(() => _isProcessing = true);

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final result = await _bookingService.performCheckIn(
      booking: _booking!,
      guest: _guest!,
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/success',
      (route) => false,
      arguments: result,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_booking == null || _guest == null) {
      return const Scaffold(
        body: Center(child: Text('No data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Check-In'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.darkBg, AppTheme.darkSurface],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Room assignment banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.goldGradientDecoration,
                child: Column(
                  children: [
                    const Icon(
                      Icons.meeting_room_rounded,
                      size: 40,
                      color: Color(0xFF1A1A2E),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'YOUR ROOM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _room?.roomNumber ?? 'TBD',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      '${_room?.typeLabel ?? ''} • Floor ${_room?.floor ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A2A0E),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Guest summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.darkGlassDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('GUEST'),
                    const SizedBox(height: 12),
                    _detailRow('Name', _guest!.fullName),
                    _detailRow('Email', _guest!.email),
                    _detailRow('Phone', _guest!.phone),
                    _detailRow('ID', '${_guest!.idType} — ${_guest!.idNumber}'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stay summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.darkGlassDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('STAY DETAILS'),
                    const SizedBox(height: 12),
                    _detailRow('Booking', _booking!.bookingRef),
                    _detailRow('Check-in', _dateFormat.format(_booking!.checkInDate)),
                    _detailRow('Check-out', _dateFormat.format(_booking!.checkOutDate)),
                    _detailRow('Duration', '${_booking!.nights} night${_booking!.nights > 1 ? "s" : ""}'),
                    _detailRow('Guests', '${_booking!.numberOfGuests}'),
                    if (_booking!.specialRequests.isNotEmpty)
                      _detailRow('Requests', _booking!.specialRequests),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmCheckIn,
                  child: _isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.darkBg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'PROCESSING...',
                              style: TextStyle(color: AppTheme.darkBg),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 22),
                            SizedBox(width: 10),
                            Text('CONFIRM CHECK-IN'),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                child: Text(
                  'Go Back & Edit',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.goldPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 2,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
