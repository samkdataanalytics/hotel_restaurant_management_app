import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network interface up.
///
/// This is a link-layer signal, not proof the backend is reachable — a venue's
/// wifi can be "connected" and still route nowhere. Treat it as a hint for
/// showing the offline banner and for explaining a failed write, never as a
/// precondition that gates a request. Attempts still go out and surface their
/// real error.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Convenience read that assumes online while the first value is pending, so a
/// cold start never flashes an offline banner.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});
