import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/booking.dart';
import 'package:hotel_checkin/domain/entities/guest.dart';
import 'package:hotel_checkin/domain/entities/room.dart';
import 'package:hotel_checkin/staff_mobile/data/guest_history.dart';

Guest _guest(String id, {String name = 'Ada Lovelace'}) => Guest(
      id: id,
      fullName: name,
      email: '',
      phone: '',
      idType: 'Passport',
      idNumber: '',
      nationality: '',
    );

({Booking booking, Room? room}) _stay({
  required String guestId,
  required DateTime checkIn,
  int nights = 2,
  BookingStatus status = BookingStatus.checkedOut,
  double amount = 10000,
  String requests = '',
}) =>
    (
      booking: Booking(
        id: 'b_${guestId}_${checkIn.millisecondsSinceEpoch}',
        bookingRef: 'BK-1',
        guestId: guestId,
        roomId: 'r1',
        checkInDate: checkIn,
        checkOutDate: checkIn.add(Duration(days: nights)),
        status: status,
        numberOfGuests: 1,
        totalAmount: amount,
        specialRequests: requests,
      ),
      room: null,
    );

void main() {
  group('grouping', () {
    test('attaches each stay to its own guest', () {
      final records = buildGuestHistory(
        guests: [_guest('g1', name: 'Ada'), _guest('g2', name: 'Grace')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1)),
          _stay(guestId: 'g2', checkIn: DateTime(2026, 6, 1)),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 7, 1)),
        ],
      );
      final ada = records.firstWhere((r) => r.guest.id == 'g1');
      expect(ada.stays, hasLength(2));
      expect(records.firstWhere((r) => r.guest.id == 'g2').stays, hasLength(1));
    });

    test('groups by id, not name, so namesakes stay separate', () {
      // Two different people can share a name; merging them would show one
      // person another's history.
      final records = buildGuestHistory(
        guests: [_guest('g1', name: 'John Smith'), _guest('g2', name: 'John Smith')],
        bookings: [_stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1))],
      );
      expect(records.firstWhere((r) => r.guest.id == 'g1').stays, hasLength(1));
      expect(records.firstWhere((r) => r.guest.id == 'g2').stays, isEmpty);
    });

    test('a guest with no bookings is kept, not dropped', () {
      final records = buildGuestHistory(guests: [_guest('g1')], bookings: []);
      expect(records, hasLength(1));
      expect(records.single.visitCount, 0);
    });

    test('orders a guest\'s stays newest first', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 1, 1)),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 9, 1)),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1)),
        ],
      );
      final dates = records.single.stays.map((s) => s.booking.checkInDate.month);
      expect(dates, [9, 5, 1]);
    });
  });

  group('what counts as a visit', () {
    test('cancelled bookings do not count', () {
      // Counting a no-show would make them look like a regular.
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1)),
          _stay(
              guestId: 'g1',
              checkIn: DateTime(2026, 6, 1),
              status: BookingStatus.cancelled),
        ],
      );
      expect(records.single.visitCount, 1);
      expect(records.single.isReturning, isFalse);
      // The cancelled booking is still listed, just not counted.
      expect(records.single.stays, hasLength(2));
    });

    test('a pending future booking is not yet a visit', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(
              guestId: 'g1',
              checkIn: DateTime(2026, 12, 1),
              status: BookingStatus.pending),
        ],
      );
      expect(records.single.visitCount, 0);
    });

    test('an in-house guest counts as a visit', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(
              guestId: 'g1',
              checkIn: DateTime(2026, 9, 1),
              status: BookingStatus.checkedIn),
        ],
      );
      expect(records.single.visitCount, 1);
    });

    test('returning means more than one completed stay', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1)),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 7, 1)),
        ],
      );
      expect(records.single.isReturning, isTrue);
    });
  });

  group('totals', () {
    test('spend and nights cover completed stays only', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1), nights: 3, amount: 30000),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 6, 1), nights: 2, amount: 20000),
          _stay(
              guestId: 'g1',
              checkIn: DateTime(2026, 7, 1),
              nights: 5,
              amount: 99999,
              status: BookingStatus.cancelled),
        ],
      );
      expect(records.single.totalSpend, 50000);
      expect(records.single.totalNights, 5);
    });

    test('last stay is the latest departure', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1), nights: 2),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 8, 1), nights: 4),
        ],
      );
      expect(records.single.lastStay, DateTime(2026, 8, 5));
    });

    test('no stays means no last stay, rather than a crash', () {
      final records = buildGuestHistory(guests: [_guest('g1')], bookings: []);
      expect(records.single.lastStay, isNull);
      expect(records.single.totalSpend, 0);
    });
  });

  group('preferences', () {
    test('collects past requests, de-duplicated', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1), requests: 'Quiet room'),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 6, 1), requests: 'Quiet room'),
          _stay(guestId: 'g1', checkIn: DateTime(2026, 7, 1), requests: 'High floor'),
        ],
      );
      expect(records.single.pastRequests, hasLength(2));
      expect(records.single.pastRequests, contains('Quiet room'));
    });

    test('ignores blank requests', () {
      final records = buildGuestHistory(
        guests: [_guest('g1')],
        bookings: [
          _stay(guestId: 'g1', checkIn: DateTime(2026, 5, 1), requests: '   '),
        ],
      );
      expect(records.single.pastRequests, isEmpty);
    });
  });

  test('most recent visitor sorts first, never-stayed guests last', () {
    final records = buildGuestHistory(
      guests: [
        _guest('g1', name: 'Older'),
        _guest('g2', name: 'Never'),
        _guest('g3', name: 'Recent'),
      ],
      bookings: [
        _stay(guestId: 'g1', checkIn: DateTime(2026, 2, 1)),
        _stay(guestId: 'g3', checkIn: DateTime(2026, 9, 1)),
      ],
    );
    expect(records.map((r) => r.guest.fullName), ['Recent', 'Older', 'Never']);
  });
}
