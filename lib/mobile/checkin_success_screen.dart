import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../app_theme.dart';
import '../domain/entities/booking.dart';
import '../domain/entities/check_in.dart';
import '../domain/entities/guest.dart';
import '../domain/entities/room.dart';

class CheckinSuccessScreen extends StatefulWidget {
  const CheckinSuccessScreen({super.key});

  @override
  State<CheckinSuccessScreen> createState() => _CheckinSuccessScreenState();
}

class _CheckinSuccessScreenState extends State<CheckinSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _particleController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  CheckIn? _checkIn;
  Booking? _booking;
  Guest? _guest;
  Room? _room;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _checkController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _particleController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkIn == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _checkIn = args['checkIn'] as CheckIn?;
        _booking = args['booking'] as Booking?;
        _guest = args['guest'] as Guest?;
        _room = args['room'] as Room?;
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBg,
              const Color(0xFF0D1B2A),
              AppTheme.darkBg,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Success animation
                SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Particles
                      AnimatedBuilder(
                        listenable: _particleController,
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(200, 140),
                            painter: _ParticlePainter(
                              progress: _particleController.value,
                              color: AppTheme.goldPrimary,
                            ),
                          );
                        },
                      ),
                      // Checkmark circle
                      AnimatedBuilder(
                        listenable: _checkController,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _checkOpacity.value,
                            child: Transform.scale(
                              scale: _checkScale.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.goldPrimary,
                                      AppTheme.goldLight,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppTheme.goldPrimary.withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 52,
                                  color: AppTheme.darkBg,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Check-In Complete!',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.goldPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome, ${_guest?.fullName ?? 'Guest'}!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 32),

                // Room card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: AppTheme.goldGradientDecoration,
                  child: Column(
                    children: [
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
                        _room?.roomNumber ?? '-',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_room?.typeLabel ?? ''} • Floor ${_room?.floor ?? ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3A2A0E),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Info cards
                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        Icons.wifi_rounded,
                        'WiFi',
                        'GrandLuxe-Guest',
                        'Pass: Welcome2024',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoCard(
                        Icons.restaurant_rounded,
                        'Breakfast',
                        '7:00 — 10:30',
                        '2nd Floor Restaurant',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        Icons.pool_rounded,
                        'Pool & Spa',
                        '6:00 — 22:00',
                        'Ground Floor',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoCard(
                        Icons.room_service_rounded,
                        'Room Service',
                        '24 Hours',
                        'Dial 0 from room',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Done button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                    child: const Text('DONE'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enjoy your stay!',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
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

  Widget _infoCard(IconData icon, String title, String line1, String line2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.darkGlassDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.goldPrimary, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.goldPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            line1,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            line2,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget? child;
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;
  final _random = math.Random(42);

  _ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final radius = 30 + _random.nextDouble() * 80 * progress;
      final particleSize = (1 - progress) * (2 + _random.nextDouble() * 4);

      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius - progress * 20,
      );

      paint.color = Color.lerp(
        color,
        color.withOpacity(0),
        progress,
      )!;

      canvas.drawCircle(offset, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
