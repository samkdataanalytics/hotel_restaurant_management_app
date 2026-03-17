import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../di/injection_container.dart';
import '../../domain/entities/booking.dart';
import '../../domain/usecases/lookup_booking.dart';

class BookingLookupScreen extends StatefulWidget {
  const BookingLookupScreen({super.key});

  @override
  State<BookingLookupScreen> createState() => _BookingLookupScreenState();
}

class _BookingLookupScreenState extends State<BookingLookupScreen>
    with SingleTickerProviderStateMixin {
  final _refController = TextEditingController();
  final _lookupBooking = sl<LookupBooking>();
  bool _isSearching = false;
  String? _errorMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _refController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _searchBooking() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      setState(() => _errorMessage = 'Please enter a booking reference');
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    final result = await _lookupBooking(ref);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'No booking found with reference "$ref"';
      });
      _shakeController.forward(from: 0);
    } else {
      final booking = result['booking'] as Booking;
      if (booking.status == BookingStatus.checkedIn) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'This booking has already been checked in';
        });
        _shakeController.forward(from: 0);
      } else if (booking.status == BookingStatus.cancelled) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'This booking has been cancelled';
        });
        _shakeController.forward(from: 0);
      } else {
        setState(() => _isSearching = false);
        Navigator.pushNamed(context, '/guest-details', arguments: result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Booking'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBg,
              AppTheme.darkSurface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.goldPrimary.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 32,
                    color: AppTheme.goldPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions
              Center(
                child: Text(
                  'Enter Your Booking Reference',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'You can find this in your confirmation email',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 40),

              // Input field
              _AnimatedBuilder(
                listenable: _shakeController,
                builder: (context, child) {
                  final offset = _shakeController.isAnimating
                      ? 10.0 *
                          (0.5 - _shakeController.value).abs() *
                          (_shakeController.value < 0.5 ? 1 : -1)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: TextField(
                  controller: _refController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'e.g. BK-001',
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      color: AppTheme.goldPrimary,
                    ),
                    errorText: _errorMessage,
                    errorStyle: TextStyle(color: Colors.redAccent.shade200),
                  ),
                  onSubmitted: (_) => _searchBooking(),
                ),
              ),
              const SizedBox(height: 32),

              // Search button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchBooking,
                  child: _isSearching
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.darkBg,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded),
                            SizedBox(width: 10),
                            Text('LOOK UP BOOKING'),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 48),

              // Sample bookings hint
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.darkGlassDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.goldPrimary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Demo Bookings',
                          style: TextStyle(
                            color: AppTheme.goldPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDemoRef('BK-001', 'James Anderson — Standard'),
                    _buildDemoRef('BK-002', 'Sophie Martin — Deluxe'),
                    _buildDemoRef('BK-005', 'Hiroshi Tanaka — Suite'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoRef(String ref, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          _refController.text = ref;
          setState(() => _errorMessage = null);
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ref,
                style: TextStyle(
                  color: AppTheme.goldLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                desc,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext, Widget?) builder;

  const _AnimatedBuilder({
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
