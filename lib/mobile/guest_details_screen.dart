import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../models/room.dart';

class GuestDetailsScreen extends StatefulWidget {
  const GuestDetailsScreen({super.key});

  @override
  State<GuestDetailsScreen> createState() => _GuestDetailsScreenState();
}

class _GuestDetailsScreenState extends State<GuestDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  String _selectedIdType = 'Passport';
  String _nationality = '';
  final _dateFormat = DateFormat('MMM dd, yyyy');

  Map<String, dynamic>? _bookingData;
  Booking? _booking;
  Guest? _guest;
  Room? _room;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bookingData == null) {
      _bookingData =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (_bookingData != null) {
        _booking = _bookingData!['booking'] as Booking;
        _guest = _bookingData!['guest'] as Guest?;
        _room = _bookingData!['room'] as Room?;

        if (_guest != null) {
          _nameController.text = _guest!.fullName;
          _emailController.text = _guest!.email;
          _phoneController.text = _guest!.phone;
          _idNumberController.text = _guest!.idNumber;
          _selectedIdType = _guest!.idType;
          _nationality = _guest!.nationality;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedGuest = _guest?.copyWith(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        nationality: _nationality,
      );

      Navigator.pushNamed(context, '/confirm', arguments: {
        'booking': _booking,
        'guest': updatedGuest,
        'room': _room,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booking == null) {
      return const Scaffold(
        body: Center(child: Text('No booking data')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Details'),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Booking summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.darkGlassDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Booking ${_booking!.bookingRef}',
                            style: TextStyle(
                              color: AppTheme.goldPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.goldPrimary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _room?.typeLabel ?? '',
                              style: TextStyle(
                                color: AppTheme.goldLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.calendar_today_rounded,
                        '${_dateFormat.format(_booking!.checkInDate)} — ${_dateFormat.format(_booking!.checkOutDate)}',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.nights_stay_rounded,
                        '${_booking!.nights} night${_booking!.nights > 1 ? "s" : ""}',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        Icons.people_outline_rounded,
                        '${_booking!.numberOfGuests} guest${_booking!.numberOfGuests > 1 ? "s" : ""}',
                      ),
                      if (_booking!.specialRequests.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildInfoRow(
                          Icons.note_outlined,
                          _booking!.specialRequests,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'Verify Your Identity',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Please confirm your details below',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Form fields
                _buildLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Email'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Valid email required' : null,
                ),
                const SizedBox(height: 16),

                _buildLabel('Phone'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('ID Type'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedIdType,
                    dropdownColor: AppTheme.darkCard,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'Driver License', child: Text('Driver License')),
                      DropdownMenuItem(value: 'National ID', child: Text('National ID')),
                    ],
                    onChanged: (v) => setState(() => _selectedIdType = v ?? 'Passport'),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('ID Number'),
                TextFormField(
                  controller: _idNumberController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'ID number is required' : null,
                ),
                const SizedBox(height: 32),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _proceed,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined),
                        SizedBox(width: 10),
                        Text('VERIFY & CONTINUE'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.goldPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
