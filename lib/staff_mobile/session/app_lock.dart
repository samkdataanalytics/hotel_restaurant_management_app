import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// How long the app may sit in the background before it re-locks.
///
/// Long enough to survive taking a phone call or checking a message mid-order,
/// short enough that a handset left on the pass is not open to whoever picks it
/// up next.
const _lockAfter = Duration(minutes: 2);

const _biometricPreferenceKey = 'hotrest_staff_biometric_lock';

class AppLockState {
  /// The user has opted into biometric locking on this device.
  final bool enabled;

  /// The device actually has enrolled biometrics available right now.
  final bool available;

  /// The lock screen should be covering the app.
  final bool locked;

  const AppLockState({
    this.enabled = false,
    this.available = false,
    this.locked = false,
  });

  AppLockState copyWith({bool? enabled, bool? available, bool? locked}) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        available: available ?? this.available,
        locked: locked ?? this.locked,
      );
}

/// Biometric re-unlock for shared devices.
///
/// The problem this solves: a handset lives behind the pass and passes between
/// people across a shift. Signing out and back in between every handover means
/// typing a password on a greasy screen with a table waiting, so in practice
/// nobody does it and the session stays open to everyone. A biometric check on
/// resume keeps the session but re-establishes who is holding the phone.
///
/// Opt-in, and it degrades rather than traps: if biometrics stop being
/// available (a device reset, an unenrolled sensor) the lock does not strand a
/// signed-in user — [unlock] reports failure and the lock screen offers a way
/// out via sign-out.
class AppLockController extends Notifier<AppLockState>
    with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  DateTime? _backgroundedAt;

  @override
  AppLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _load();
    return const AppLockState();
  }

  Future<void> _load() async {
    final available = await _checkAvailable();
    var enabled = false;
    try {
      enabled = (await _storage.read(key: _biometricPreferenceKey)) == 'true';
    } catch (e) {
      debugPrint('AppLock: could not read preference: $e');
    }
    state = state.copyWith(enabled: enabled, available: available);
  }

  Future<bool> _checkAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      // isDeviceSupported() is true for a device passcode alone. Require an
      // actual enrolled biometric, since a passcode prompt is no faster than
      // typing the password we are trying to avoid.
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('AppLock: availability check failed: $e');
      return false;
    }
  }

  /// Turns the lock on or off. Enabling prompts once, so the user confirms the
  /// sensor works before relying on it.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final available = await _checkAvailable();
      if (!available) {
        state = state.copyWith(available: false);
        return false;
      }
      final ok = await _authenticate('Confirm to turn on biometric unlock');
      if (!ok) return false;
    }

    try {
      await _storage.write(
        key: _biometricPreferenceKey,
        value: value.toString(),
      );
    } catch (e) {
      debugPrint('AppLock: could not persist preference: $e');
      return false;
    }

    state = state.copyWith(enabled: value, available: true, locked: false);
    return true;
  }

  /// Prompts for the biometric and clears the lock on success.
  Future<bool> unlock() async {
    final ok = await _authenticate('Unlock to return to your shift');
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  /// Called on sign-out so the next user does not inherit a locked screen.
  void reset() {
    _backgroundedAt = null;
    state = state.copyWith(locked: false);
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // Allow the device passcode as a fallback: at the unlock prompt the
        // alternative to a failed sensor is being locked out mid-service.
        biometricOnly: false,
        // Survive the OS briefly backgrounding the app to show the prompt,
        // which would otherwise cancel the attempt on Android.
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('AppLock: authentication failed: $e');
      return false;
    }
  }

  // The base signature names this parameter `state`, which would shadow
  // Notifier.state — the very thing this method reads and writes. Renamed
  // deliberately; the lint does not know about the collision.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (!state.enabled) return;

    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && DateTime.now().difference(since) >= _lockAfter) {
          state = state.copyWith(locked: true);
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // inactive fires for a notification shade pull or the app switcher —
        // too transient to start the clock on.
        break;
    }
  }
}

final appLockProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
