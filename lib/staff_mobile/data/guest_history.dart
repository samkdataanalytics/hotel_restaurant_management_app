import '../../domain/entities/booking.dart';
import '../../domain/entities/guest.dart';
import '../../domain/entities/room.dart';

/// A guest and everything their stays add up to.
class GuestRecord {
  final Guest guest;

  /// Newest first.
  final List<({Booking booking, Room? room})> stays;

  const GuestRecord({required this.guest, this.stays = const []});

  /// Stays that actually happened — a cancelled booking is not a visit, and
  /// counting it would make a no-show look like a regular.
  List<Booking> get completedStays => stays
      .map((s) => s.booking)
      .where((b) =>
          b.status == BookingStatus.checkedOut ||
          b.status == BookingStatus.checkedIn)
      .toList();

  int get visitCount => completedStays.length;

  /// Room revenue across completed stays. Restaurant and extras are not
  /// included: those live on the folio per booking, and pulling them for every
  /// guest in a list would be dozens of extra queries for a number nobody is
  /// making a decision on at the front desk.
  double get totalSpend =>
      completedStays.fold(0.0, (sum, b) => sum + b.totalAmount);

  int get totalNights => completedStays.fold(
      0, (sum, b) => sum + b.checkOutDate.difference(b.checkInDate).inDays.clamp(0, 999));

  DateTime? get lastStay {
    if (completedStays.isEmpty) return null;
    return completedStays
        .map((b) => b.checkOutDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Someone worth recognising at the desk.
  bool get isReturning => visitCount > 1;

  /// Anything the guest asked for before, so it can be offered again without
  /// them having to ask twice.
  List<String> get pastRequests => stays
      .map((s) => s.booking.specialRequests.trim())
      .where((r) => r.isNotEmpty)
      .toSet()
      .toList();
}

/// Builds guest records from the enriched booking rows.
///
/// Grouped by guest id rather than by name: two guests can share a name, and
/// merging them would show one person another's history.
List<GuestRecord> buildGuestHistory({
  required List<Guest> guests,
  required List<({Booking booking, Room? room})> bookings,
}) {
  final byGuest = <String, List<({Booking booking, Room? room})>>{};
  for (final entry in bookings) {
    byGuest.putIfAbsent(entry.booking.guestId, () => []).add(entry);
  }

  for (final list in byGuest.values) {
    list.sort((a, b) => b.booking.checkInDate.compareTo(a.booking.checkInDate));
  }

  final records = [
    for (final guest in guests)
      GuestRecord(guest: guest, stays: byGuest[guest.id] ?? const []),
  ];

  // Most recent visitor first; guests who have never stayed sink to the bottom
  // rather than being dropped, since a booking-only record is still someone the
  // desk may need to look up.
  records.sort((a, b) {
    final aLast = a.lastStay;
    final bLast = b.lastStay;
    if (aLast == null && bLast == null) {
      return a.guest.fullName.toLowerCase().compareTo(b.guest.fullName.toLowerCase());
    }
    if (aLast == null) return 1;
    if (bLast == null) return -1;
    return bLast.compareTo(aLast);
  });

  return records;
}
