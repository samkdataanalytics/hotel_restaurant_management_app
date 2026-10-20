import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Full-screen branded hold, shown while the session resolves on a cold start.
///
/// This is the hand-off from the native launch screen, which is the same
/// lockup centred on white. Matching it means the app appears to hold one
/// image while it loads, instead of flashing a bare spinner under an app bar
/// the moment Flutter takes over — on a slow connection that flash was the
/// first thing staff saw.
///
/// No app bar on purpose: a chrome bar titled "HotRest" above a logo is the
/// brand twice, and there is nothing to navigate back to yet.
class BrandSplash extends StatelessWidget {
  /// Shown under the logo. A cold start is usually fast enough that this never
  /// registers, so it carries no text by default.
  final String? message;

  const BrandSplash({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // White rather than the scaffold tint, so it matches the native splash
      // exactly — the lockup is supplied on a transparent ground.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(width: 240),
              const SizedBox(height: 40),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: scheme.primary,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
