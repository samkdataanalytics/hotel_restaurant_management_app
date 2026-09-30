import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/front_desk_repository.dart';
import '../../data/scanned_code.dart';
import '../../router/staff_router.dart';
import '../../session/staff_session.dart';

/// Scan a table, room or booking code.
///
/// Reads the QR codes the web panel already generates and venues already have
/// printed, rather than a staff-only format that would mean reprinting
/// everything. See [parseScannedCode].
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );

  /// Set once a code has been accepted, so the camera cannot fire a second
  /// navigation while the first is still in flight.
  bool _handled = false;
  String? _rejection;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_photography_outlined,
                        size: 48, color: scheme.error),
                    const SizedBox(height: 16),
                    Text(
                      'The camera is unavailable. Check the permission in '
                      'device settings.\n\n${error.errorCode.name}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // A plain reticle. A fancier overlay costs frames on the cheap
          // handsets this runs on, and the camera preview is already the hint.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rejection ??
                        'Point at a table, room or booking code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _rejection == null
                          ? Colors.white
                          : scheme.errorContainer,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: _rejection == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final code = parseScannedCode(raw);
    final session = ref.read(staffSessionProvider).valueOrNull;
    final activeProperty = session?.activeProperty?.id;

    // A code from another property must not open anything. RLS would refuse
    // the reads anyway, but the failure would surface as an empty screen
    // rather than an explanation.
    String? foreignProperty;
    if (code is ScannedTable && code.propertyId != activeProperty) {
      foreignProperty = code.propertyId;
    } else if (code is ScannedRoom && code.propertyId != activeProperty) {
      foreignProperty = code.propertyId;
    }
    if (foreignProperty != null) {
      _reject('That code belongs to a different property. Switch property '
          'first, then scan again.');
      return;
    }

    switch (code) {
      case ScannedTable(:final tableId):
        if (session == null || !session.canEdit('restaurant_pos')) {
          _reject('You do not have permission to take orders.');
          return;
        }
        _handled = true;
        await context.push(StaffRoutes.orderEntry(tableId));
        if (mounted) Navigator.of(context).pop();

      case ScannedBooking(:final bookingRef):
        if (session == null || !session.canEdit('hotel_checkins')) {
          _reject('You do not have permission to check guests in.');
          return;
        }
        _handled = true;
        await _openBooking(bookingRef);

      case ScannedRoom(:final roomNumber):
        // Room QRs are the guest's room-service entry point; for staff the
        // useful response is the room's own queue, not the guest menu.
        _reject('Room $roomNumber — room service orders are on the Orders tab.');

      case ScannedUnknown():
        _reject('That code is not a HotRest table, room or booking.');
    }
  }

  Future<void> _openBooking(String bookingRef) async {
    try {
      final stay =
          await ref.read(frontDeskRepositoryProvider).lookupBooking(bookingRef);
      if (!mounted) return;

      if (stay == null) {
        _handled = false;
        _reject('No booking matches $bookingRef on this property.');
        return;
      }

      await context.push(StaffRoutes.checkIn, extra: stay);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _handled = false;
      _reject('Could not look that booking up: $e');
    }
  }

  /// Shows why a scan was refused, then re-arms after a moment so the next
  /// attempt is not blocked by a stale message.
  void _reject(String message) {
    if (!mounted) return;
    setState(() => _rejection = message);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _rejection = null);
    });
  }
}
