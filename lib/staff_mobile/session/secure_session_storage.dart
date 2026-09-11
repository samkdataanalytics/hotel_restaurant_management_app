import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the platform keystore instead of
/// SharedPreferences.
///
/// Staff devices are shared and often not the staff member's own — a handset
/// behind the pass, a tablet on the bar. The default
/// [SharedPreferencesLocalStorage] writes the refresh token as plaintext in app
/// storage, which is readable on a rooted or jailbroken device and included in
/// some backup paths. Keychain (iOS) / EncryptedSharedPreferences (Android)
/// closes that.
///
/// Mobile only. The web app keeps the supabase_flutter default — this class is
/// never reachable from `lib/main.dart`.
class SecureSessionStorage extends LocalStorage {
  static const _sessionKey = 'hotrest_staff_session';

  final FlutterSecureStorage _storage;

  const SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Android encrypts by default from v10 — the old
              // `encryptedSharedPreferences` flag is deprecated and ignored.
              //
              // first_unlock rather than the default: the app needs to restore
              // a session on launch after a device reboot, before the user has
              // unlocked the phone in this session. whenUnlocked would return
              // null there and silently sign staff out every reboot.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _read()) != null;

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _sessionKey, value: persistSessionString);
    } catch (e) {
      // A keystore write can fail on a device with a corrupted or reset
      // keystore. Failing loudly here would block sign-in entirely; the session
      // still works for this launch, the user just signs in again next time.
      debugPrint('SecureSessionStorage: could not persist session: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('SecureSessionStorage: could not clear session: $e');
    }
  }

  Future<String?> _read() async {
    try {
      return await _storage.read(key: _sessionKey);
    } catch (e) {
      // Most commonly a decryption failure after an OS restore onto a new
      // device, where the keystore key did not come across. Treat it as "no
      // session" and drop the unreadable blob so it cannot fail forever.
      debugPrint('SecureSessionStorage: could not read session: $e');
      await removePersistedSession();
      return null;
    }
  }
}
