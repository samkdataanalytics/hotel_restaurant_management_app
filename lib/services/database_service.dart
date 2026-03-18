import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import '../models/guest.dart';
import '../models/booking.dart';
import '../models/room.dart';
import '../models/check_in.dart';
import '../models/expense.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final _uuid = const Uuid();

  // In-memory storage (works on both web and mobile)
  final Map<String, Guest> _guests = {};
  final Map<String, Booking> _bookings = {};
  final Map<String, Room> _rooms = {};
  final Map<String, CheckIn> _checkIns = {};
  final Map<String, Expense> _expenses = {};

  // Auto-increment booking reference counter
  int _bookingRefCounter = 0;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _seedData();
    _initialized = true;
  }

  // ─── Booking Ref Generation ──────────────────────────────

  String generateNextBookingRef() {
    _bookingRefCounter++;
    return 'BK-${_bookingRefCounter.toString().padLeft(3, '0')}';
  }

  // ─── Guest CRUD ──────────────────────────────────────────

  Future<Guest?> getGuest(String id) async => _guests[id];

  Future<List<Guest>> getAllGuests() async => _guests.values.toList();

  Future<void> insertGuest(Guest guest) async {
    _guests[guest.id] = guest;
  }

  Future<void> updateGuest(Guest guest) async {
    _guests[guest.id] = guest;
  }

  // ─── Room CRUD ───────────────────────────────────────────

  Future<Room?> getRoom(String id) async => _rooms[id];

  Future<List<Room>> getAllRooms() async {
    final list = _rooms.values.toList();
    list.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    return list;
  }

  Future<void> updateRoom(Room room) async {
    _rooms[room.id] = room;
  }

  Future<void> insertRoom(Room room) async {
    _rooms[room.id] = room;
  }

  Future<void> deleteRoom(String id) async {
    _rooms.remove(id);
  }

  Future<List<Room>> getAvailableRooms() async {
    return _rooms.values
        .where((r) => r.status == RoomStatus.available)
        .toList();
  }

  // ─── Booking CRUD ────────────────────────────────────────

  Future<Booking?> getBooking(String id) async => _bookings[id];

  Future<List<Booking>> getAllBookings() async => _bookings.values.toList();

  Future<Booking?> getBookingByRef(String ref) async {
    try {
      return _bookings.values.firstWhere(
        (b) => b.bookingRef.toLowerCase() == ref.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> insertBooking(Booking booking) async {
    _bookings[booking.id] = booking;
  }

  Future<void> updateBooking(Booking booking) async {
    _bookings[booking.id] = booking;
  }

  Future<void> deleteBooking(String id) async {
    _bookings.remove(id);
  }

  Future<List<Booking>> getBookingsByStatus(BookingStatus status) async {
    return _bookings.values.where((b) => b.status == status).toList();
  }

  // ─── CheckIn CRUD ────────────────────────────────────────

  Future<CheckIn?> getCheckIn(String id) async => _checkIns[id];

  Future<List<CheckIn>> getAllCheckIns() async {
    final list = _checkIns.values.toList();
    list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
    return list;
  }

  Future<void> insertCheckIn(CheckIn checkIn) async {
    _checkIns[checkIn.id] = checkIn;
  }

  Future<List<CheckIn>> getTodayCheckIns() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _checkIns.values
        .where((c) => c.checkInTime.isAfter(todayStart))
        .toList();
  }

  // ─── Expense CRUD ────────────────────────────────────────

  Future<List<Expense>> getAllExpenses() async {
    final list = _expenses.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date)); // Newest first
    return list;
  }

  Future<List<Expense>> getRoomExpenses(String roomId) async {
    final list = _expenses.values.where((e) => e.roomId == roomId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<Expense>> getExpensesByBookingId(String bookingId) async {
    final list = _expenses.values
        .where((e) => e.bookingId == bookingId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> insertExpense(Expense expense) async {
    _expenses[expense.id] = expense;
  }

  Future<void> updateExpense(Expense expense) async {
    _expenses[expense.id] = expense;
  }

  Future<void> deleteExpense(String id) async {
    _expenses.remove(id);
  }

  // ─── Stats ───────────────────────────────────────────────

  Future<Map<String, int>> getDashboardStats() async {
    final todayCheckins = await getTodayCheckIns();
    final allRooms = await getAllRooms();
    final occupied =
        allRooms.where((r) => r.status == RoomStatus.occupied).length;
    final available =
        allRooms.where((r) => r.status == RoomStatus.available).length;
    final pendingBookings = await getBookingsByStatus(BookingStatus.pending);

    return {
      'todayCheckIns': todayCheckins.length,
      'occupiedRooms': occupied,
      'availableRooms': available,
      'pendingArrivals': pendingBookings.length,
      'totalRooms': allRooms.length,
    };
  }

  // ─── Seed Data ───────────────────────────────────────────

  Future<void> _seedData() async {
    final now = DateTime.now();

    // Create rooms (one with maintenance period)
    final roomData = [
      Room(id: _uuid.v4(), roomNumber: '101', type: RoomType.standard, floor: 1, status: RoomStatus.available, pricePerNight: 120.0),
      Room(id: _uuid.v4(), roomNumber: '102', type: RoomType.standard, floor: 1, status: RoomStatus.available, pricePerNight: 120.0),
      Room(id: _uuid.v4(), roomNumber: '103', type: RoomType.deluxe, floor: 1, status: RoomStatus.available, pricePerNight: 200.0),
      Room(id: _uuid.v4(), roomNumber: '201', type: RoomType.deluxe, floor: 2, status: RoomStatus.occupied, pricePerNight: 200.0),
      Room(id: _uuid.v4(), roomNumber: '202', type: RoomType.deluxe, floor: 2, status: RoomStatus.available, pricePerNight: 200.0),
      Room(id: _uuid.v4(), roomNumber: '203', type: RoomType.standard, floor: 2, status: RoomStatus.maintenance, pricePerNight: 120.0, maintenanceStart: now, maintenanceEnd: now.add(const Duration(days: 5))),
      Room(id: _uuid.v4(), roomNumber: '301', type: RoomType.suite, floor: 3, status: RoomStatus.available, pricePerNight: 350.0),
      Room(id: _uuid.v4(), roomNumber: '302', type: RoomType.suite, floor: 3, status: RoomStatus.occupied, pricePerNight: 350.0),
      Room(id: _uuid.v4(), roomNumber: '303', type: RoomType.deluxe, floor: 3, status: RoomStatus.available, pricePerNight: 220.0),
      Room(id: _uuid.v4(), roomNumber: '401', type: RoomType.suite, floor: 4, status: RoomStatus.available, pricePerNight: 500.0),
    ];

    for (final room in roomData) {
      _rooms[room.id] = room;
    }

    // Create guests
    final guestData = [
      Guest(id: _uuid.v4(), fullName: 'James Anderson', email: 'james.anderson@email.com', phone: '+1-555-0101', idType: 'Passport', idNumber: 'US12345678', nationality: 'American'),
      Guest(id: _uuid.v4(), fullName: 'Sophie Martin', email: 'sophie.martin@email.com', phone: '+33-555-0202', idType: 'Passport', idNumber: 'FR87654321', nationality: 'French'),
      Guest(id: _uuid.v4(), fullName: 'Raj Patel', email: 'raj.patel@email.com', phone: '+91-555-0303', idType: 'Passport', idNumber: 'IN11223344', nationality: 'Indian'),
      Guest(id: _uuid.v4(), fullName: 'Emma Wilson', email: 'emma.wilson@email.com', phone: '+44-555-0404', idType: 'Driver License', idNumber: 'UK99887766', nationality: 'British'),
      Guest(id: _uuid.v4(), fullName: 'Hiroshi Tanaka', email: 'h.tanaka@email.com', phone: '+81-555-0505', idType: 'Passport', idNumber: 'JP55443322', nationality: 'Japanese'),
    ];

    for (final guest in guestData) {
      _guests[guest.id] = guest;
    }

    final guestIds = guestData.map((g) => g.id).toList();
    final roomIds = roomData.map((r) => r.id).toList();

    // Create bookings with source and amounts
    final bookingData = [
      Booking(id: _uuid.v4(), bookingRef: generateNextBookingRef(), guestId: guestIds[0], roomId: roomIds[0], checkInDate: now, checkOutDate: now.add(const Duration(days: 3)), status: BookingStatus.pending, numberOfGuests: 2, specialRequests: 'Late check-in, extra pillows', source: BookingSource.bookingCom, totalAmount: 360.0, isQrGenerated: true, isQrSent: true, isGuestFormSubmitted: true, isPaid: true),
      Booking(id: _uuid.v4(), bookingRef: generateNextBookingRef(), guestId: guestIds[1], roomId: roomIds[2], checkInDate: now, checkOutDate: now.add(const Duration(days: 5)), status: BookingStatus.pending, numberOfGuests: 1, specialRequests: 'Quiet room please', source: BookingSource.airbnb, totalAmount: 1000.0, isQrGenerated: true, isQrSent: false, isPaid: false),
      Booking(id: _uuid.v4(), bookingRef: generateNextBookingRef(), guestId: guestIds[2], roomId: roomIds[3], checkInDate: now.subtract(const Duration(days: 1)), checkOutDate: now.add(const Duration(days: 2)), status: BookingStatus.checkedIn, numberOfGuests: 2, source: BookingSource.bookingCom, totalAmount: 600.0, isQrGenerated: true, isQrSent: true, isGuestFormSubmitted: true, isPaid: true),
      Booking(id: _uuid.v4(), bookingRef: generateNextBookingRef(), guestId: guestIds[3], roomId: roomIds[7], checkInDate: now.subtract(const Duration(days: 2)), checkOutDate: now.add(const Duration(days: 1)), status: BookingStatus.checkedIn, numberOfGuests: 1, specialRequests: 'Airport shuttle required', source: BookingSource.airbnb, totalAmount: 1050.0, isQrGenerated: true, isQrSent: true, isGuestFormSubmitted: true, isPaid: false),
      Booking(id: _uuid.v4(), bookingRef: generateNextBookingRef(), guestId: guestIds[4], roomId: roomIds[6], checkInDate: now.add(const Duration(days: 1)), checkOutDate: now.add(const Duration(days: 4)), status: BookingStatus.pending, numberOfGuests: 2, specialRequests: 'Honeymoon suite decoration', source: BookingSource.direct, totalAmount: 1050.0, isPaid: true),
    ];

    for (final booking in bookingData) {
      _bookings[booking.id] = booking;
    }

    // Create check-ins for already checked-in bookings
    final checkedInBookings = bookingData.where((b) => b.status == BookingStatus.checkedIn);
    for (final booking in checkedInBookings) {
      final checkIn = CheckIn(
        id: _uuid.v4(),
        bookingId: booking.id,
        guestId: booking.guestId,
        roomId: booking.roomId,
        checkInTime: booking.checkInDate.add(const Duration(hours: 14)),
        idVerified: true,
        keyIssued: true,
      );
      _checkIns[checkIn.id] = checkIn;
    }

    // Create expenses
    final expenseData = [
      Expense(id: _uuid.v4(), description: 'Plumbing repair', amount: 150.0, category: ExpenseCategory.maintenance, date: now.subtract(const Duration(days: 2)), roomId: roomIds[5]), // room 203 (maintenance)
      Expense(id: _uuid.v4(), description: 'Deep cleaning', amount: 80.0, category: ExpenseCategory.cleaning, date: now.subtract(const Duration(days: 5)), roomId: roomIds[2]),
      Expense(id: _uuid.v4(), description: 'Electricity bill', amount: 450.0, category: ExpenseCategory.utilities, date: now.subtract(const Duration(days: 10))),
      Expense(id: _uuid.v4(), description: 'New towels', amount: 120.0, category: ExpenseCategory.supplies, date: now.subtract(const Duration(days: 1))),
      Expense(
        id: _uuid.v4(),
        description: 'Room Service (Breakfast)',
        amount: 45.0,
        category: ExpenseCategory.other,
        date: now.subtract(const Duration(days: 1)),
        roomId: roomIds[0],
        isBillable: true,
        bookingId: _checkIns.values.first.bookingId, // Link to completed check-in booking
      ),
      Expense(
        id: _uuid.v4(),
        description: 'Linen refresh package',
        amount: 210.0,
        category: ExpenseCategory.supplies,
        date: now.subtract(const Duration(days: 3)),
        endDate: now.subtract(const Duration(days: 1)), // 3-day period
      ),
    ];

    for (final expense in expenseData) {
      _expenses[expense.id] = expense;
    }
  }
}
