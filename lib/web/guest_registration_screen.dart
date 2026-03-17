import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/booking.dart';
import '../models/guest.dart';
import '../services/booking_service.dart';

class GuestRegistrationScreen extends StatefulWidget {
  final String bookingRef;

  const GuestRegistrationScreen({super.key, required this.bookingRef});

  @override
  State<GuestRegistrationScreen> createState() => _GuestRegistrationScreenState();
}

class _GuestRegistrationScreenState extends State<GuestRegistrationScreen> {
  final _bookingService = BookingService();
  bool _isLoading = true;
  String? _error;

  Booking? _booking;
  Guest? _guest;
  
  // Section 1: Guest Information
  final _fullNameCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _whatsAppCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  DateTime? _dateOfBirth;

  // Section 3: Additional Services
  String _bikeRental = 'No';
  String _airportTransfer = 'No';
  String _surfingLessons = 'No';
  String _yogaLessons = 'No';
  String _whaleWatching = 'No';
  String _safaris = 'None';
  final _specialRequestsCtrl = TextEditingController();

  final _dateFormatter = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final data = await _bookingService.lookupBooking(widget.bookingRef);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _error = 'Invalid booking reference.';
        _isLoading = false;
      });
      return;
    }

    _booking = data['booking'] as Booking;
    _guest = data['guest'] as Guest;

    if (_booking!.isGuestFormSubmitted) {
      setState(() {
        _error = 'Registration form already submitted for this booking.';
        _isLoading = false;
      });
      return;
    }

    _fullNameCtrl.text = _guest!.fullName;
    _emailCtrl.text = _guest!.email;
    _passportCtrl.text = _guest!.passportOrNic ?? _guest!.idNumber;
    _nationalityCtrl.text = _guest!.nationality;
    _whatsAppCtrl.text = _guest!.whatsApp ?? _guest!.phone;
    _dateOfBirth = _guest!.dateOfBirth;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: AppTheme.webTheme.copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.adminPrimary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_fullNameCtrl.text.isEmpty || _passportCtrl.text.isEmpty || _emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields in Section 1.'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Update Guest
    final updatedGuest = _guest!.copyWith(
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      passportOrNic: _passportCtrl.text.trim(),
      nationality: _nationalityCtrl.text.trim(),
      whatsApp: _whatsAppCtrl.text.trim(),
      dateOfBirth: _dateOfBirth,
    );
    await _bookingService.updateGuest(updatedGuest);

    // Collect Preferences
    final preferences = {
      'bikeRental': _bikeRental,
      'airportTransfer': _airportTransfer,
      'surfingLessons': _surfingLessons,
      'yogaLessons': _yogaLessons,
      'whaleWatching': _whaleWatching,
      'safaris': _safaris,
      'specialRequests': _specialRequestsCtrl.text.trim(),
    };

    // Update Booking
    final updatedBooking = _booking!.copyWith(
      isGuestFormSubmitted: true,
      guestPreferences: preferences,
      specialRequests: _specialRequestsCtrl.text.trim().isNotEmpty ? _specialRequestsCtrl.text.trim() : _booking!.specialRequests,
    );
    await _bookingService.updateBooking(updatedBooking);

    setState(() {
      _error = 'SUCCESS';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _passportCtrl.dispose();
    _nationalityCtrl.dispose();
    _whatsAppCtrl.dispose();
    _emailCtrl.dispose();
    _specialRequestsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error == 'SUCCESS') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 80, color: AppTheme.success),
              const SizedBox(height: 24),
              const Text('Thank you!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your check-in details have been received.', style: TextStyle(fontSize: 18, color: Colors.black54)),
              const SizedBox(height: 32),
              const Text('We look forward to welcoming you soon.', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 80, color: AppTheme.danger),
              const SizedBox(height: 24),
              Text(_error!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Guest Pre-Registration'),
        backgroundColor: AppTheme.sidebarDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            children: [
              const Text(
                'Welcome to Grand Luxe Hotel',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please complete this form to expedite your check-in process.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // SECTION 1: Guest Information
              _buildSectionHeader('Section 1: Guest Information'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildTextField('Full Name *', _fullNameCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Passport / NIC Number *', _passportCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Nationality', _nationalityCtrl),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                          ),
                          child: Text(_dateOfBirth == null ? 'Select Date' : _dateFormatter.format(_dateOfBirth!)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField('WhatsApp Number', _whatsAppCtrl),
                      const SizedBox(height: 16),
                      _buildTextField('Email Address *', _emailCtrl),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // SECTION 2: Booking Details
              _buildSectionHeader('Section 2: Booking Details'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDetailRow('Booking Reference', _booking!.bookingRef),
                      const Divider(height: 24),
                      _buildDetailRow('Check-In Date', _dateFormatter.format(_booking!.checkInDate)),
                      const Divider(height: 24),
                      _buildDetailRow('Check-Out Date', _dateFormatter.format(_booking!.checkOutDate)),
                      const Divider(height: 24),
                      _buildDetailRow('Number of Guests', _booking!.numberOfGuests.toString()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // SECTION 3: Additional Services
              _buildSectionHeader('Section 3: Additional Services (Optional)'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDropdown(
                        'Would you like to rent a bike/scooter?',
                        _bikeRental,
                        ['Yes', 'No', 'Maybe Later'],
                        (val) => setState(() => _bikeRental = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Airport Pickup or Drop Required?',
                        _airportTransfer,
                        ['Yes - Pickup', 'Yes - Drop', 'Yes - Both', 'No', 'Maybe Later'],
                        (val) => setState(() => _airportTransfer = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Surfing Lessons?',
                        _surfingLessons,
                        ['Beginner', 'Intermediate', 'No', 'Maybe Later'],
                        (val) => setState(() => _surfingLessons = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Yoga Lessons?',
                        _yogaLessons,
                        ['Yes', 'No', 'Maybe Later'],
                        (val) => setState(() => _yogaLessons = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Whale Watching?',
                        _whaleWatching,
                        ['Yes', 'No', 'Maybe Later'],
                        (val) => setState(() => _whaleWatching = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildDropdown(
                        'Safaris?',
                        _safaris,
                        ['Udawalawa', 'Yala', 'Both', 'None', 'Maybe Later'],
                        (val) => setState(() => _safaris = val!),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField('Any special requests?', _specialRequestsCtrl, maxLines: 3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.adminPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.adminPrimary),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
