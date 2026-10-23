import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String hotelId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.hotelId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.metadata,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        hotelId: hotelId,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        metadata: metadata,
        createdAt: createdAt,
      );

  factory AppNotification.fromMap(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        hotelId: r['hotel_id'] as String,
        type: r['type'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        isRead: r['is_read'] as bool? ?? false,
        metadata: (r['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class NotificationService {
  final _db = Supabase.instance.client;
  final String hotelId;

  NotificationService(this.hotelId);

  // ── Recipient targeting ─────────────────────────────────────────────────
  // Notifications are hotel-wide by default. Tagging `metadata.recipient_user_id`
  // targets a single staff member; untagged notifications remain visible to
  // everyone. Filtering happens client-side so no schema change is needed.

  static bool _visibleTo(AppNotification n, String? viewerUserId) {
    final recipient = n.metadata['recipient_user_id'] as String?;
    if (recipient == null) return true;
    return recipient == viewerUserId;
  }

  // ── Fetch recent notifications (last 50) ──────────────────────────────────

  Future<List<AppNotification>> getNotifications({String? viewerUserId}) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('hotel_id', hotelId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map<AppNotification>(AppNotification.fromMap)
        .where((n) => _visibleTo(n, viewerUserId))
        .toList();
  }

  // ── Real-time stream ──────────────────────────────────────────────────────

  Stream<List<AppNotification>> watchNotifications({String? viewerUserId}) {
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('hotel_id', hotelId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((rows) => rows
            .map(AppNotification.fromMap)
            .where((n) => _visibleTo(n, viewerUserId))
            .toList());
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<void> create({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _db.from('notifications').insert({
        'hotel_id': hotelId,
        'type': type,
        'title': title,
        'body': body,
        'metadata': metadata,
      });
    } catch (_) {
      // Non-critical — never block the main action for a notification failure
    }
  }

  // ── Mark as read ──────────────────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('hotel_id', hotelId);
  }

  Future<void> markAllAsRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('hotel_id', hotelId)
        .eq('is_read', false);
  }

  // ── Housekeeping fallback (called on app login) ───────────────────────────
  // If pg_cron is not enabled, the Dart app checks manually on login.
  // Calls the same SQL function via rpc.

  Future<void> checkHousekeeping() async {
    try {
      await _db.rpc('generate_housekeeping_notifications');
    } catch (_) {
      // pg_cron may handle it; silently ignore if rpc not needed
    }
  }

  // ── Convenience creators ──────────────────────────────────────────────────

  Future<void> notifyNewReservation({
    required String guestName,
    required String roomNumber,
    required String bookingRef,
    required String checkIn,
    required String checkOut,
  }) =>
      create(
        type: 'reservation',
        title: 'New Reservation — $bookingRef',
        body: '$guestName booked Room $roomNumber ($checkIn → $checkOut)',
        metadata: {'booking_ref': bookingRef, 'room_number': roomNumber},
      );

  Future<void> notifyCheckIn({
    required String guestName,
    required String roomNumber,
    required String bookingRef,
  }) =>
      create(
        type: 'checkin',
        title: 'Guest Checked In — Room $roomNumber',
        body: '$guestName has checked in to Room $roomNumber',
        metadata: {'booking_ref': bookingRef, 'room_number': roomNumber},
      );

  Future<void> notifyCheckOut({
    required String guestName,
    required String roomNumber,
    required String bookingRef,
  }) =>
      create(
        type: 'checkout',
        title: 'Guest Checked Out — Room $roomNumber',
        body: '$guestName has checked out from Room $roomNumber',
        metadata: {'booking_ref': bookingRef, 'room_number': roomNumber},
      );

  Future<void> notifyLowAvailability({
    required int availableRooms,
    required int totalRooms,
  }) =>
      create(
        type: 'low_availability',
        title: 'Low Room Availability',
        body:
            'Only $availableRooms of $totalRooms rooms are available. Consider adjusting rates.',
        metadata: {
          'available_rooms': availableRooms,
          'total_rooms': totalRooms,
        },
      );

  Future<void> notifyRoomServiceOrder({
    required String orderNumber,
    required String roomNumber,
    required int itemCount,
    required double total,
  }) =>
      create(
        type: 'room_service',
        title: 'Room Service Order — Room $roomNumber',
        body:
            'Order #$orderNumber placed from Room $roomNumber ($itemCount item${itemCount == 1 ? '' : 's'}, \$$total)',
        metadata: {
          'order_number': orderNumber,
          'room_number': roomNumber,
        },
      );

  /// Targeted at a single staff member — only visible to [recipientUserId]
  /// (see [_visibleTo]). Used for shift add/edit/delete/copy-week alerts.
  Future<void> notifyShiftChange({
    required String recipientUserId,
    required String title,
    required String body,
  }) =>
      create(
        type: 'shift_change',
        title: title,
        body: body,
        metadata: {'recipient_user_id': recipientUserId},
      );
}
