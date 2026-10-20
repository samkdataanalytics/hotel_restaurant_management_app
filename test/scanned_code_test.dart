import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_checkin/staff_mobile/data/scanned_code.dart';

void main() {
  group('table QR', () {
    test('parses the format the web panel generates', () {
      final result =
          parseScannedCode('https://hotrest.app/menu/prop-123/table-456');
      expect(result, isA<ScannedTable>());
      final table = result as ScannedTable;
      expect(table.propertyId, 'prop-123');
      expect(table.tableId, 'table-456');
    });

    test('works regardless of host, since the origin varies by deployment', () {
      for (final origin in [
        'https://hotrest.app',
        'https://www.hotrest.app',
        'https://hotrest-dev.vercel.app',
        'http://localhost:8080',
      ]) {
        final result = parseScannedCode('$origin/menu/p1/t1');
        expect(result, isA<ScannedTable>(), reason: origin);
      }
    });

    test('tolerates a trailing slash', () {
      expect(parseScannedCode('https://hotrest.app/menu/p1/t1/'),
          isA<ScannedTable>());
    });
  });

  group('room QR', () {
    test('parses the room-service format', () {
      final result =
          parseScannedCode('https://hotrest.app/room-service/prop-1/204');
      expect(result, isA<ScannedRoom>());
      expect((result as ScannedRoom).roomNumber, '204');
    });
  });

  group('booking QR', () {
    test('parses the guest-registration link', () {
      final result = parseScannedCode(
          'https://hotrest.app/guest-registration?ref=BK-0042');
      expect(result, isA<ScannedBooking>());
      expect((result as ScannedBooking).bookingRef, 'BK-0042');
    });

    test('a guest-registration link with no ref is not a booking', () {
      expect(parseScannedCode('https://hotrest.app/guest-registration'),
          isA<ScannedUnknown>());
    });

    test('accepts a bare reference from a printed barcode', () {
      expect(parseScannedCode('BK-0007'), isA<ScannedBooking>());
    });

    test('accepts a bare reference in any case', () {
      expect(parseScannedCode('bk-0007'), isA<ScannedBooking>());
    });

    test('does not assume a fixed digit count, since the sequence grows', () {
      expect(parseScannedCode('BK-123456'), isA<ScannedBooking>());
    });

    test('rejects something merely resembling a reference', () {
      for (final value in ['BK', 'BK-', 'BKX-1', '0001', 'TABLE-1']) {
        expect(parseScannedCode(value), isA<ScannedUnknown>(),
            reason: value);
      }
    });
  });

  group('anything else', () {
    test('an unrelated URL is unknown, not silently mis-routed', () {
      final result = parseScannedCode('https://example.com/some/page');
      expect(result, isA<ScannedUnknown>());
      expect((result as ScannedUnknown).raw, 'https://example.com/some/page');
    });

    test('plain text is unknown', () {
      expect(parseScannedCode('hello world'), isA<ScannedUnknown>());
    });

    test('an empty scan is unknown rather than a crash', () {
      expect(parseScannedCode(''), isA<ScannedUnknown>());
      expect(parseScannedCode('   '), isA<ScannedUnknown>());
    });

    test('surrounding whitespace is trimmed', () {
      expect(parseScannedCode('  BK-0007  '), isA<ScannedBooking>());
    });

    test('a menu path missing its table id is not a table', () {
      expect(parseScannedCode('https://hotrest.app/menu/prop-1'),
          isA<ScannedUnknown>());
    });
  });
}
