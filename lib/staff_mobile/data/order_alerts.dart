import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';
import 'orders_realtime.dart';

/// Alerts staff when a new order lands, while the app is running.
///
/// This is the half of F-06 that needs no Firebase project: a local
/// notification fired from the existing `restaurant_orders` realtime
/// subscription. It covers the case that actually matters minute to minute —
/// a kitchen tablet propped on a shelf, awake, with nobody staring at it.
///
/// What it does NOT do is wake a killed or backgrounded app. That needs true
/// remote push (FCM/APNs) plus a server-side trigger, and is tracked separately
/// because it requires Firebase credentials and a backend change.
///
/// Deliberately fires only on INSERT. Bumping an order through cooking → ready
/// would otherwise alert everyone several times for one order.
class OrderAlerts {
  static const _prefKey = 'hotrest_staff_order_alerts';

  static const _channelId = 'hotrest_new_orders';
  static const _channelName = 'New orders';
  static const _channelDescription =
      'Alerts when a new order arrives for this property.';

  final FlutterLocalNotificationsPlugin _plugin;
  final LocalStore _store;

  OrderAlerts(this._store, {FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  int _nextId = 0;

  /// Sets up the plugin. Does not request permission — that is asked for only
  /// when someone turns alerts on, so a first launch is not met with a prompt
  /// for something they have not opted into.
  Future<void> init() async {
    if (_initialised) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            // Deferred to the explicit opt-in below.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialised = true;
    } catch (e) {
      debugPrint('OrderAlerts: init failed, alerts unavailable: $e');
    }
  }

  bool get isEnabled => _store.readCache('device', _prefKey)?.value == true;

  /// Turns alerts on or off, requesting OS permission on the way on.
  /// Returns whether alerts are enabled afterwards.
  Future<bool> setEnabled(bool value) async {
    if (!value) {
      await _store.writeCache('device', _prefKey, false);
      return false;
    }

    await init();
    final granted = await _requestPermission();
    await _store.writeCache('device', _prefKey, granted);
    return granted;
  }

  Future<bool> _requestPermission() async {
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Android 13+ requires POST_NOTIFICATIONS at runtime; older versions
        // return null here and are granted by manifest.
        return await android.requestNotificationsPermission() ?? true;
      }
      return false;
    } catch (e) {
      debugPrint('OrderAlerts: permission request failed: $e');
      return false;
    }
  }

  /// Shows the alert for one new order.
  Future<void> notifyNewOrder(OrderChange change) async {
    if (!isEnabled) return;
    await init();
    if (!_initialised) return;

    final where = switch (change.type) {
      'roomService' => 'Room service',
      'takeaway' => 'Takeaway',
      'delivery' => 'Delivery',
      _ => 'Table order',
    };
    final count = change.itemCount;

    try {
      await _plugin.show(
        id: _nextId++,
        title: 'New order · $where',
        body: '#${change.orderNumber ?? '—'} · $count item'
            '${count == 1 ? '' : 's'}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            // A kitchen is loud and nobody is watching the screen.
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      // An alert failing must never disturb the order flow that triggered it.
      debugPrint('OrderAlerts: could not show notification: $e');
    }
  }
}

/// Exposes whether alerts are on as reactive state, so the menu that toggles
/// it re-renders without anyone poking the element tree.
class OrderAlertsController extends Notifier<bool> {
  late final OrderAlerts _alerts = OrderAlerts(ref.read(localStoreProvider));

  @override
  bool build() => _alerts.isEnabled;

  /// Returns whether alerts are enabled afterwards. A false result when the
  /// caller asked for true means the OS refused permission.
  Future<bool> setEnabled(bool value) async {
    final result = await _alerts.setEnabled(value);
    state = result;
    return result;
  }

  Future<void> notifyNewOrder(OrderChange change) =>
      _alerts.notifyNewOrder(change);
}

final orderAlertsProvider =
    NotifierProvider<OrderAlertsController, bool>(OrderAlertsController.new);

/// Bridges the realtime stream to the alert service.
///
/// Watched once from the shell so it lives as long as a signed-in session,
/// rather than being tied to whichever tab happens to be on screen.
final orderAlertListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<OrderChange>>(ordersRealtimeProvider, (_, next) {
    final change = next.valueOrNull;
    if (change == null || !change.isNewOrder) return;
    ref.read(orderAlertsProvider.notifier).notifyNewOrder(change);
  });
});
