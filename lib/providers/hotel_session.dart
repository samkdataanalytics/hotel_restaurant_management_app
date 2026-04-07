import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _db => Supabase.instance.client;

// ─── Staff roles (mirrors staff_role DB enum) ─────────────────────────────────
enum StaffRole { owner, manager, frontDesk, kitchen, restaurant }

StaffRole _parseRole(String? raw) {
  switch (raw) {
    case 'owner':       return StaffRole.owner;
    case 'manager':     return StaffRole.manager;
    case 'kitchen':     return StaffRole.kitchen;
    case 'restaurant':  return StaffRole.restaurant;
    default:            return StaffRole.frontDesk;
  }
}

// ─── Brand color helper ───────────────────────────────────────────────────────
Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  if (h.length == 8) return Color(int.parse(h,     radix: 16));
  return const Color(0xFFD4A853); // fallback gold
}

// ─── Immutable settings snapshot ──────────────────────────────────────────────
class HotelSettings {
  final String hotelId;
  final String displayName;
  final String address;
  final String phone;
  final String email;
  final String currencySymbol;
  final double taxRate;
  final double serviceChargeRate;
  final String logoUrl;
  /// Hex string e.g. '#D4A853'. Use [primaryColor] for a Flutter Color.
  final String primaryColorHex;

  const HotelSettings({
    required this.hotelId,
    required this.displayName,
    required this.address,
    required this.phone,
    required this.email,
    required this.currencySymbol,
    required this.taxRate,
    required this.serviceChargeRate,
    required this.logoUrl,
    this.primaryColorHex = '#D4A853',
  });

  Color get primaryColor => hexToColor(primaryColorHex);

  factory HotelSettings.fromRow(Map<String, dynamic> r) => HotelSettings(
        hotelId:           r['hotel_id']             as String,
        displayName:       r['display_name']         as String? ?? '',
        address:           r['address']              as String? ?? '',
        phone:             r['phone']                as String? ?? '',
        email:             r['email']                as String? ?? '',
        currencySymbol:    r['currency_symbol']      as String? ?? '\$',
        taxRate:           (r['tax_rate']            as num?)?.toDouble() ?? 0.0,
        serviceChargeRate: (r['service_charge_rate'] as num?)?.toDouble() ?? 0.00,
        logoUrl:           r['logo_url']             as String? ?? '',
        primaryColorHex:   r['primary_color']        as String? ?? '#D4A853',
      );
}

// ─── Session provider ──────────────────────────────────────────────────────────
/// Holds the currently logged-in staff member's hotel context.
/// Wrap the app with `ChangeNotifierProvider<HotelSession>` in main.dart.
class HotelSession extends ChangeNotifier {
  String?       _hotelId;
  StaffRole?    _role;
  HotelSettings? _settings;
  bool          _loading = false;
  String?       _error;

  // ── Getters ────────────────────────────────────────────────────────────────
  String?        get hotelId   => _hotelId;
  StaffRole?     get role      => _role;
  HotelSettings? get settings  => _settings;
  bool           get loading   => _loading;
  String?        get error     => _error;
  bool           get isLoggedIn => _hotelId != null;

  /// Convenience: true when staff may access admin functions.
  bool get isManager =>
      _role == StaffRole.owner || _role == StaffRole.manager;

  // ── Sign in ────────────────────────────────────────────────────────────────
  /// Authenticates with Supabase, then loads hotel_id + settings.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn(String email, String password) async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      // 1. Supabase auth
      final res = await _db.auth.signInWithPassword(
        email:    email,
        password: password,
      );
      if (res.user == null) {
        _loading = false;
        _error   = 'Authentication failed.';
        notifyListeners();
        return _error;
      }

      // 2. Look up hotel membership
      final userRows = await _db
          .from('hotel_users')
          .select('hotel_id, role')
          .eq('user_id', res.user!.id)
          .limit(1);

      if (userRows.isEmpty) {
        await _db.auth.signOut();
        _loading = false;
        _error   = 'Your account is not linked to any hotel. Contact your administrator.';
        notifyListeners();
        return _error;
      }

      _hotelId = userRows.first['hotel_id'] as String;
      _role    = _parseRole(userRows.first['role'] as String?);

      // 3. Load hotel settings
      await _refreshSettings();

      _loading = false;
      notifyListeners();
      return null; // success

    } on AuthException catch (e) {
      _loading = false;
      _error   = e.message;
      notifyListeners();
      return _error;
    } catch (e) {
      _loading = false;
      _error   = 'Unexpected error: $e';
      notifyListeners();
      return _error;
    }
  }

  // ── Reload settings (call after saving hotel_settings) ─────────────────────
  Future<void> _refreshSettings() async {
    if (_hotelId == null) return;
    final rows = await _db
        .from('hotel_settings')
        .select()
        .eq('hotel_id', _hotelId!)
        .limit(1);
    if (rows.isNotEmpty) {
      _settings = HotelSettings.fromRow(rows.first);
    }
  }

  Future<void> reloadSettings() async {
    await _refreshSettings();
    notifyListeners();
  }

  // ── Restore session on app start ───────────────────────────────────────────
  /// Call once during app init.  If a Supabase session already exists
  /// (e.g. browser local storage), restore the hotel context silently.
  Future<void> restoreSession() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return;

      final userRows = await _db
          .from('hotel_users')
          .select('hotel_id, role')
          .eq('user_id', user.id)
          .limit(1);

      if (userRows.isEmpty) return;

      _hotelId = userRows.first['hotel_id'] as String;
      _role    = _parseRole(userRows.first['role'] as String?);
      await _refreshSettings();
      notifyListeners();
    } catch (_) {
      // Session restore failed (e.g. expired token or missing policy).
      // App will show the login screen — user signs in normally.
    }
  }

  // ── Set hotel id directly (used by AppShell when switching properties) ──────
  /// Sets the active hotel context without going through signIn.
  /// Also clears settings so they can be refreshed on demand.
  Future<void> setHotelId(String id) async {
    _hotelId = id;
    _role = StaffRole.manager;
    await _refreshSettings();
    notifyListeners();
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _db.auth.signOut();
    _hotelId  = null;
    _role     = null;
    _settings = null;
    _error    = null;
    notifyListeners();
  }
}
