import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
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
              AppTheme.darkSurface,
              AppTheme.darkBg,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Hotel icon
                Container(
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
                        color: AppTheme.goldPrimary.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.hotel_rounded,
                    size: 48,
                    color: AppTheme.darkBg,
                  ),
                ),
                const SizedBox(height: 32),

                // Hotel name
                Text(
                  'HOTREST MANAGEMENT',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    letterSpacing: 6,
                    color: AppTheme.goldPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'H O T E L  &  R E S O R T',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    letterSpacing: 4,
                    color: AppTheme.textMuted,
                  ),
                ),

                const Spacer(flex: 1),

                // Welcome message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        'Welcome',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Begin your seamless check-in experience.\nIt only takes a moment.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // CTA Button with pulse
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/lookup');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 22),
                          SizedBox(width: 12),
                          Text('START CHECK-IN'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary info
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Need help? Contact front desk',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // Bottom decoration line
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
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
}
