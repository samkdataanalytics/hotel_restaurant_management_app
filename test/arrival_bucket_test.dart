import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/domain/entities/booking.dart';
import 'package:hotel_checkin/staff_mobile/data/front_desk_repository.dart';

/// `today` for every case, so the assertions read against a fixed calendar.
final _today = DateTime(2026, 9, 15);

ArrivalEntry _entry({
  required BookingStatus status,
  required DateTime checkIn,
  required DateTime checkOut,
}) =>
    ArrivalEntry(
      booking: Booking(
        id: 'b1',
        bookingRef: 'BK-0001',
        guestId: 'g1',
        roomId: 'r1',
        checkInDate: checkIn,
        checkOutDate: checkOut,
        status: status,
        numberOfGuests: 2,
      ),
    );

void main() {
  group('ArrivalEntry.bucketFor', () {
    test('pending arriving today is an arrival', () {
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 15, 14),
        checkOut: DateTime(2026, 9, 18),
      );
      expect(e.bucketFor(_today), ArrivalBucket.arrivingToday);
    });

    test('pending arriving later is upcoming', () {
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 20),
        checkOut: DateTime(2026, 9, 22),
      );
      expect(e.bucketFor(_today), ArrivalBucket.upcoming);
    });

    test('a pending booking whose date has passed stays under arrivals', () {
      // A no-show must remain visible to the desk. Dropping it into "upcoming"
      // or hiding it entirely is how a booking gets silently forgotten.
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 12),
        checkOut: DateTime(2026, 9, 14),
      );
      expect(e.bucketFor(_today), ArrivalBucket.arrivingToday);
    });

    test('checked in and leaving today is a departure', () {
      final e = _entry(
        status: BookingStatus.checkedIn,
        checkIn: DateTime(2026, 9, 13),
        checkOut: DateTime(2026, 9, 15, 11),
      );
      expect(e.bucketFor(_today), ArrivalBucket.departingToday);
    });

    test('checked in and staying on is in house', () {
      final e = _entry(
        status: BookingStatus.checkedIn,
        checkIn: DateTime(2026, 9, 13),
        checkOut: DateTime(2026, 9, 19),
      );
      expect(e.bucketFor(_today), ArrivalBucket.inHouse);
    });

    test('checked in past its departure date is still a departure', () {
      // An overstay needs chasing, so it belongs on the departures list rather
      // than sitting quietly in house.
      final e = _entry(
        status: BookingStatus.checkedIn,
        checkIn: DateTime(2026, 9, 10),
        checkOut: DateTime(2026, 9, 13),
      );
      expect(e.bucketFor(_today), ArrivalBucket.departingToday);
    });

    test('cancelled and checked out are excluded entirely', () {
      for (final status in [BookingStatus.cancelled, BookingStatus.checkedOut]) {
        final e = _entry(
          status: status,
          checkIn: DateTime(2026, 9, 15),
          checkOut: DateTime(2026, 9, 17),
        );
        expect(e.bucketFor(_today), isNull, reason: '$status should not show');
      }
    });

    test('a time of day on the arrival date does not change the bucket', () {
      // Bucketing compares calendar days, not instants — a 23:30 arrival is
      // still arriving today.
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 15, 23, 30),
        checkOut: DateTime(2026, 9, 16),
      );
      expect(e.bucketFor(_today), ArrivalBucket.arrivingToday);
    });
  });

  group('ArrivalEntry display helpers', () {
    test('nights is the span between the two dates', () {
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 15),
        checkOut: DateTime(2026, 9, 18),
      );
      expect(e.nights, 3);
    });

    test('nights never goes negative on inverted dates', () {
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 18),
        checkOut: DateTime(2026, 9, 15),
      );
      expect(e.nights, 0);
    });

    test('falls back to placeholders when guest and room are missing', () {
      final e = _entry(
        status: BookingStatus.pending,
        checkIn: DateTime(2026, 9, 15),
        checkOut: DateTime(2026, 9, 16),
      );
      expect(e.guestName, 'Guest');
      expect(e.roomLabel, 'Unassigned');
    });
  });
}
