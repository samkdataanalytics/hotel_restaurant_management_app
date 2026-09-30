/// What a scanned code turned out to be.
sealed class ScannedCode {
  const ScannedCode();
}

/// A table QR, from `{origin}/menu/{propertyId}/{tableId}`.
class ScannedTable extends ScannedCode {
  final String propertyId;
  final String tableId;
  const ScannedTable({required this.propertyId, required this.tableId});
}

/// A guest room QR, from `{origin}/room-service/{propertyId}/{roomNumber}`.
class ScannedRoom extends ScannedCode {
  final String propertyId;
  final String roomNumber;
  const ScannedRoom({required this.propertyId, required this.roomNumber});
}

/// A booking, either from `{origin}/guest-registration?ref=BK-0001` or from a
/// bare reference printed as a barcode on a confirmation.
class ScannedBooking extends ScannedCode {
  final String bookingRef;
  const ScannedBooking(this.bookingRef);
}

/// Scanned successfully, but not something this app knows what to do with.
class ScannedUnknown extends ScannedCode {
  final String raw;
  const ScannedUnknown(this.raw);
}

/// Interprets the contents of a scanned code.
///
/// Deliberately parses the **existing** QR formats the web panel already
/// generates rather than inventing a staff-only one. Venues have these codes
/// printed and stuck to tables and room doors already; a new format would mean
/// reprinting everything, and the codes in the wild would silently not work.
///
/// Matching is on path shape, not on host, because the origin varies by
/// deployment (hotrest.app, a dev Vercel URL, localhost) and a scanner that
/// only accepted production URLs would be untestable and would break for any
/// customer on a custom domain.
ScannedCode parseScannedCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const ScannedUnknown('');

  final uri = Uri.tryParse(trimmed);

  if (uri != null && uri.hasScheme) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.length >= 3 && segments[0] == 'menu') {
      return ScannedTable(propertyId: segments[1], tableId: segments[2]);
    }

    if (segments.length >= 3 && segments[0] == 'room-service') {
      return ScannedRoom(propertyId: segments[1], roomNumber: segments[2]);
    }

    if (segments.isNotEmpty && segments[0] == 'guest-registration') {
      final ref = uri.queryParameters['ref'];
      if (ref != null && ref.trim().isNotEmpty) {
        return ScannedBooking(ref.trim());
      }
    }

    return ScannedUnknown(trimmed);
  }

  // Not a URL. A bare booking reference is the one plain string worth
  // recognising — confirmations are sometimes printed with the reference as a
  // barcode rather than a QR.
  if (_looksLikeBookingRef(trimmed)) return ScannedBooking(trimmed);

  return ScannedUnknown(trimmed);
}

/// References are generated as `BK-0001` by getNextBookingRef.
///
/// Matched case-insensitively and without assuming a digit count, since the
/// sequence grows.
bool _looksLikeBookingRef(String value) =>
    RegExp(r'^BK-\d+$', caseSensitive: false).hasMatch(value);
