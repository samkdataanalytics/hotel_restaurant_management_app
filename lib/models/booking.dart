enum BookingStatus { pending, checkedIn, checkedOut, cancelled }

enum BookingSource { bookingCom, airbnb, direct, other }

class Booking {
  final String id;
  final String bookingRef;
  final String guestId;
  final String roomId;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final BookingStatus status;
  final int numberOfGuests;
  final String specialRequests;
  final BookingSource source;
  final double totalAmount;
  final bool isQrGenerated;
  final bool isQrSent;
  final bool isGuestFormSubmitted;
  final bool isPaid;
  final Map<String, dynamic>? guestPreferences;

  Booking({
    required this.id,
    required this.bookingRef,
    required this.guestId,
    required this.roomId,
    required this.checkInDate,
    required this.checkOutDate,
    required this.status,
    required this.numberOfGuests,
    this.specialRequests = '',
    this.source = BookingSource.direct,
    this.totalAmount = 0.0,
    this.isQrGenerated = false,
    this.isQrSent = false,
    this.isGuestFormSubmitted = false,
    this.isPaid = false,
    this.guestPreferences,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingRef': bookingRef,
      'guestId': guestId,
      'roomId': roomId,
      'checkInDate': checkInDate.toIso8601String(),
      'checkOutDate': checkOutDate.toIso8601String(),
      'status': status.name,
      'numberOfGuests': numberOfGuests,
      'specialRequests': specialRequests,
      'source': source.name,
      'totalAmount': totalAmount,
      'isQrGenerated': isQrGenerated,
      'isQrSent': isQrSent,
      'isGuestFormSubmitted': isGuestFormSubmitted,
      'isPaid': isPaid,
      'guestPreferences': guestPreferences,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String,
      bookingRef: map['bookingRef'] as String,
      guestId: map['guestId'] as String,
      roomId: map['roomId'] as String,
      checkInDate: DateTime.parse(map['checkInDate'] as String),
      checkOutDate: DateTime.parse(map['checkOutDate'] as String),
      status: BookingStatus.values.firstWhere((e) => e.name == map['status']),
      numberOfGuests: map['numberOfGuests'] as int,
      specialRequests: (map['specialRequests'] as String?) ?? '',
      source: BookingSource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? 'direct'),
        orElse: () => BookingSource.direct,
      ),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      isQrGenerated: map['isQrGenerated'] as bool? ?? false,
      isQrSent: map['isQrSent'] as bool? ?? false,
      isGuestFormSubmitted: map['isGuestFormSubmitted'] as bool? ?? false,
      isPaid: map['isPaid'] as bool? ?? false,
      guestPreferences: map['guestPreferences'] as Map<String, dynamic>?,
    );
  }

  Booking copyWith({
    String? id,
    String? bookingRef,
    String? guestId,
    String? roomId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    BookingStatus? status,
    int? numberOfGuests,
    String? specialRequests,
    BookingSource? source,
    double? totalAmount,
    bool? isQrGenerated,
    bool? isQrSent,
    bool? isGuestFormSubmitted,
    bool? isPaid,
    Map<String, dynamic>? guestPreferences,
  }) {
    return Booking(
      id: id ?? this.id,
      bookingRef: bookingRef ?? this.bookingRef,
      guestId: guestId ?? this.guestId,
      roomId: roomId ?? this.roomId,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      status: status ?? this.status,
      numberOfGuests: numberOfGuests ?? this.numberOfGuests,
      specialRequests: specialRequests ?? this.specialRequests,
      source: source ?? this.source,
      totalAmount: totalAmount ?? this.totalAmount,
      isQrGenerated: isQrGenerated ?? this.isQrGenerated,
      isQrSent: isQrSent ?? this.isQrSent,
      isGuestFormSubmitted: isGuestFormSubmitted ?? this.isGuestFormSubmitted,
      isPaid: isPaid ?? this.isPaid,
      guestPreferences: guestPreferences ?? this.guestPreferences,
    );
  }

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.checkedIn:
        return 'Checked In';
      case BookingStatus.checkedOut:
        return 'Checked Out';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get sourceLabel {
    switch (source) {
      case BookingSource.bookingCom:
        return 'Booking.com';
      case BookingSource.airbnb:
        return 'Airbnb';
      case BookingSource.direct:
        return 'Direct';
      case BookingSource.other:
        return 'Other';
    }
  }

  int get nights => checkOutDate.difference(checkInDate).inDays;
}
