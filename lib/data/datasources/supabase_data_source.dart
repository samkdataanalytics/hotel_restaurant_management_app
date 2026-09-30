import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/guest.dart';
import '../../domain/entities/room.dart';

class SupabaseDataSource {
  static final SupabaseDataSource _instance = SupabaseDataSource._internal();
  factory SupabaseDataSource() => _instance;
  SupabaseDataSource._internal();

  final _uuid = const Uuid();
  SupabaseClient get _db => Supabase.instance.client;

  String? hotelId;

  // ─── Mappers ─────────────────────────────────────────────────────────────

  Guest _guestFromRow(Map<String, dynamic> r) => Guest.fromMap({
        'id': r['id'],
        'fullName': r['full_name'],
        'email': r['email'],
        'phone': r['phone'],
        'idType': r['id_type'],
        'idNumber': r['id_number'],
        'nationality': r['nationality'],
        'passportOrNic': r['passport_or_nic'],
        'dateOfBirth': r['date_of_birth'],
        'whatsApp': r['whats_app'],
      });

  Map<String, dynamic> _guestToRow(Guest g) => {
        'id': g.id,
        'full_name': g.fullName,
        'email': g.email,
        'phone': g.phone,
        'id_type': g.idType,
        'id_number': g.idNumber,
        'nationality': g.nationality,
        'passport_or_nic': g.passportOrNic,
        'date_of_birth': g.dateOfBirth?.toIso8601String(),
        'whats_app': g.whatsApp,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  Room _roomFromRow(Map<String, dynamic> r) => Room.fromMap({
        'id': r['id'],
        'roomNumber': r['room_number'],
        'type': r['type'],
        'floor': r['floor'],
        'status': r['status'],
        'pricePerNight': r['price_per_night'],
        'maintenanceStart': r['maintenance_start'],
        'maintenanceEnd': r['maintenance_end'],
        'housekeeping': r['housekeeping_status'],
      });

  Map<String, dynamic> _roomToRow(Room r) => {
        'id': r.id,
        'room_number': r.roomNumber,
        'type': r.type.name,
        'floor': r.floor,
        'status': r.status.name,
        'price_per_night': r.pricePerNight,
        'maintenance_start': r.maintenanceStart?.toIso8601String(),
        'maintenance_end': r.maintenanceEnd?.toIso8601String(),
        'housekeeping_status': r.housekeeping.name,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  Booking _bookingFromRow(Map<String, dynamic> r) => Booking.fromMap({
        'id': r['id'],
        'bookingRef': r['booking_ref'],
        'guestId': r['guest_id'],
        'roomId': r['room_id'],
        'checkInDate': r['check_in_date'],
        'checkOutDate': r['check_out_date'],
        'status': r['status'],
        'numberOfGuests': r['number_of_guests'],
        'specialRequests': r['special_requests'] ?? '',
        'source': r['source'] ?? 'direct',
        'totalAmount': r['total_amount'],
        'isQrGenerated': r['is_qr_generated'] ?? false,
        'isQrSent': r['is_qr_sent'] ?? false,
        'isGuestFormSubmitted': r['is_guest_form_submitted'] ?? false,
        'isPaid': r['is_paid'] ?? false,
        'guestPreferences': r['guest_preferences'],
      });

  Map<String, dynamic> _bookingToRow(Booking b) => {
        'id': b.id,
        'booking_ref': b.bookingRef,
        'guest_id': b.guestId,
        'room_id': b.roomId,
        'check_in_date': b.checkInDate.toIso8601String(),
        'check_out_date': b.checkOutDate.toIso8601String(),
        'status': b.status.name,
        'number_of_guests': b.numberOfGuests,
        'special_requests': b.specialRequests,
        'source': b.source.name,
        'total_amount': b.totalAmount,
        'is_qr_generated': b.isQrGenerated,
        'is_qr_sent': b.isQrSent,
        'is_guest_form_submitted': b.isGuestFormSubmitted,
        'is_paid': b.isPaid,
        'guest_preferences': b.guestPreferences,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  CheckIn _checkInFromRow(Map<String, dynamic> r) => CheckIn.fromMap({
        'id': r['id'],
        'bookingId': r['booking_id'],
        'guestId': r['guest_id'],
        'roomId': r['room_id'],
        'checkInTime': r['check_in_time'],
        'idVerified': r['id_verified'],
        'keyIssued': r['key_issued'],
        'idDocumentUrl': r['id_document_url'],
        'signatureUrl': r['signature_url'],
      });

  Map<String, dynamic> _checkInToRow(CheckIn c) => {
        'id': c.id,
        'booking_id': c.bookingId,
        'guest_id': c.guestId,
        'room_id': c.roomId,
        'check_in_time': c.checkInTime.toIso8601String(),
        'id_verified': c.idVerified,
        'key_issued': c.keyIssued,
        if (c.idDocumentUrl != null) 'id_document_url': c.idDocumentUrl,
        if (c.signatureUrl != null) 'signature_url': c.signatureUrl,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  Expense _expenseFromRow(Map<String, dynamic> r) => Expense.fromMap({
        'id': r['id'],
        'description': r['description'],
        'amount': r['amount'],
        'category': r['category'],
        'date': r['date'],
        'endDate': r['end_date'],
        'roomId': r['room_id'],
        'isBillable': r['is_billable'] ?? false,
        'isPaid': r['is_paid'] ?? false,
        'bookingId': r['booking_id'],
        'receiptUrl': r['receipt_url'],
      });

  Map<String, dynamic> _expenseToRow(Expense e) => {
        'id': e.id,
        'description': e.description,
        'amount': e.amount,
        'category': e.category.name,
        'date': e.date.toIso8601String(),
        'end_date': e.endDate?.toIso8601String(),
        'room_id': e.roomId,
        'is_billable': e.isBillable,
        'is_paid': e.isPaid,
        'booking_id': e.bookingId,
        if (e.receiptUrl != null) 'receipt_url': e.receiptUrl,
        if (hotelId != null) 'hotel_id': hotelId,
      };

  // ─── Guests ──────────────────────────────────────────────────────────────

  Future<Guest?> getGuest(String id) async {
    final rows = await _db.from('guests').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return _guestFromRow(rows.first);
  }

  Future<List<Guest>> getAllGuests() async {
    if (hotelId == null) return [];
    final rows = await _db.from('guests').select().eq('hotel_id', hotelId!).order('full_name');
    return rows.map(_guestFromRow).toList();
  }

  Future<void> insertGuest(Guest guest) async {
    await _db.from('guests').insert(_guestToRow(guest));
  }

  Future<void> updateGuest(Guest guest) async {
    await _db.from('guests').upsert(_guestToRow(guest));
  }

  Future<void> deleteGuest(String id) async {
    await _db.from('guests').delete().eq('id', id);
  }

  // ─── Rooms ───────────────────────────────────────────────────────────────

  Future<Room?> getRoom(String id) async {
    final rows = await _db.from('rooms').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return _roomFromRow(rows.first);
  }

  Future<List<Room>> getAllRooms() async {
    if (hotelId == null) return [];
    final rows = await _db.from('rooms').select().eq('hotel_id', hotelId!).order('room_number');
    return rows.map(_roomFromRow).toList();
  }

  Future<void> insertRoom(Room room) async {
    await _db.from('rooms').insert(_roomToRow(room));
  }

  Future<void> updateRoom(Room room) async {
    await _db.from('rooms').update(_roomToRow(room)).eq('id', room.id);
  }

  Future<void> deleteRoom(String id) async {
    await _db.from('rooms').delete().eq('id', id);
  }

  Future<List<Room>> getAvailableRooms() async {
    if (hotelId == null) return [];
    final rows = await _db.from('rooms').select().eq('hotel_id', hotelId!).eq('status', 'available');
    return rows.map(_roomFromRow).toList();
  }

  // ─── Bookings ────────────────────────────────────────────────────────────

  Future<Booking?> getBooking(String id) async {
    final rows = await _db.from('bookings').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return _bookingFromRow(rows.first);
  }

  Future<List<Booking>> getAllBookings() async {
    if (hotelId == null) return [];
    final rows = await _db.from('bookings').select().eq('hotel_id', hotelId!).order('created_at', ascending: false);
    return rows.map(_bookingFromRow).toList();
  }

  Future<Booking?> getBookingByRef(String ref) async {
    if (hotelId == null) return null;
    final rows = await _db.from('bookings').select().eq('hotel_id', hotelId!).eq('booking_ref', ref).limit(1);
    if (rows.isEmpty) return null;
    return _bookingFromRow(rows.first);
  }

  Future<void> insertBooking(Booking booking) async {
    await _db.from('bookings').insert(_bookingToRow(booking));
  }

  Future<void> updateBooking(Booking booking) async {
    await _db.from('bookings').update(_bookingToRow(booking)).eq('id', booking.id);
  }

  Future<void> deleteBooking(String id) async {
    await _db.from('bookings').delete().eq('id', id);
  }

  Future<List<Booking>> getBookingsByStatus(BookingStatus status) async {
    if (hotelId == null) return [];
    final rows = await _db.from('bookings').select().eq('hotel_id', hotelId!).eq('status', status.name);
    return rows.map(_bookingFromRow).toList();
  }

  Future<String> getNextBookingRef() async {
    if (hotelId == null) return 'REF-000';
    final rows = await _db
        .from('bookings')
        .select('booking_ref')
        .eq('hotel_id', hotelId!)
        .order('booking_ref', ascending: false)
        .limit(1);

    if (rows.isEmpty) return 'REF-001';
    final lastRef = rows.first['booking_ref'] as String;
    final lastNum = int.tryParse(lastRef.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'REF-${(lastNum + 1).toString().padLeft(3, '0')}';
  }

  Future<int> countPendingArrivalsToday() async {
    if (hotelId == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final tomorrow = DateTime(now.year, now.month, now.day + 1).toIso8601String();

    final response = await _db
        .from('bookings')
        .select('id')
        .eq('hotel_id', hotelId!)
        .eq('status', BookingStatus.pending.name)
        .gte('check_in_date', today)
        .lt('check_in_date', tomorrow)
        .count(CountOption.exact);

    return response.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getEnrichedBookings() async {
    if (hotelId == null) return [];
    // Join with guests and rooms
    final rows = await _db
        .from('bookings')
        .select('*, guests(*), rooms(*)')
        .eq('hotel_id', hotelId!)
        .order('created_at', ascending: false);

    return rows.map((r) {
      return {
        'booking': _bookingFromRow(r),
        'guest': r['guests'] != null ? _guestFromRow(r['guests']) : null,
        'room': r['rooms'] != null ? _roomFromRow(r['rooms']) : null,
      };
    }).toList();
  }

  // ─── Check-Ins ───────────────────────────────────────────────────────────

  Future<CheckIn?> getCheckIn(String id) async {
    final rows = await _db.from('check_ins').select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return _checkInFromRow(rows.first);
  }

  Future<List<CheckIn>> getAllCheckIns() async {
    if (hotelId == null) return [];
    final rows = await _db.from('check_ins').select().eq('hotel_id', hotelId!).order('check_in_time', ascending: false);
    return rows.map(_checkInFromRow).toList();
  }

  Future<void> insertCheckIn(CheckIn checkIn) async {
    await _db.from('check_ins').insert(_checkInToRow(checkIn));
  }

  Future<List<CheckIn>> getTodayCheckIns() async {
    if (hotelId == null) return [];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await _db.from('check_ins').select().eq('hotel_id', hotelId!).gte('check_in_time', todayStart);
    return rows.map(_checkInFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> getEnrichedCheckIns() async {
    if (hotelId == null) return [];
    final rows = await _db
        .from('check_ins')
        .select('*, bookings(*), guests(*), rooms(*)')
        .eq('hotel_id', hotelId!)
        .order('check_in_time', ascending: false);

    return rows.map((r) {
      return {
        'checkIn': _checkInFromRow(r),
        'booking': r['bookings'] != null ? _bookingFromRow(r['bookings']) : null,
        'guest': r['guests'] != null ? _guestFromRow(r['guests']) : null,
        'room': r['rooms'] != null ? _roomFromRow(r['rooms']) : null,
      };
    }).toList();
  }

  // ─── Expenses ────────────────────────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    if (hotelId == null) return [];
    final rows = await _db.from('expenses').select().eq('hotel_id', hotelId!).order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<List<Expense>> getRoomExpenses(String roomId) async {
    final rows = await _db.from('expenses').select().eq('room_id', roomId).order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<List<Expense>> getExpensesByBookingId(String bookingId) async {
    final rows = await _db.from('expenses').select().eq('booking_id', bookingId).order('date', ascending: false);
    return rows.map(_expenseFromRow).toList();
  }

  Future<void> insertExpense(Expense expense) async {
    await _db.from('expenses').insert(_expenseToRow(expense));
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.from('expenses').update(_expenseToRow(expense)).eq('id', expense.id);
  }

  Future<void> deleteExpense(String id) async {
    await _db.from('expenses').delete().eq('id', id);
  }
}
