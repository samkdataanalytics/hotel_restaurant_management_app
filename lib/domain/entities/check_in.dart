class CheckIn {
  final String id;
  final String bookingId;
  final String guestId;
  final String roomId;
  final DateTime checkInTime;
  final bool idVerified;
  final bool keyIssued;

  /// Object path in the private `guest-documents` bucket, or null when no
  /// document was captured. Nullable because a desk must still be able to check
  /// someone in when the camera is unavailable.
  final String? idDocumentUrl;
  final String? signatureUrl;

  CheckIn({
    required this.id,
    required this.bookingId,
    required this.guestId,
    required this.roomId,
    required this.checkInTime,
    required this.idVerified,
    required this.keyIssued,
    this.idDocumentUrl,
    this.signatureUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'guestId': guestId,
      'roomId': roomId,
      'checkInTime': checkInTime.toIso8601String(),
      'idVerified': idVerified ? 1 : 0,
      'keyIssued': keyIssued ? 1 : 0,
      'idDocumentUrl': idDocumentUrl,
      'signatureUrl': signatureUrl,
    };
  }

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      id: map['id'] as String,
      bookingId: map['bookingId'] as String,
      guestId: map['guestId'] as String,
      roomId: map['roomId'] as String,
      checkInTime: DateTime.parse(map['checkInTime'] as String),
      idVerified: map['idVerified'] == 1 || map['idVerified'] == true,
      keyIssued: map['keyIssued'] == 1 || map['keyIssued'] == true,
      idDocumentUrl: map['idDocumentUrl'] as String?,
      signatureUrl: map['signatureUrl'] as String?,
    );
  }

  CheckIn copyWith({
    String? id,
    String? bookingId,
    String? guestId,
    String? roomId,
    DateTime? checkInTime,
    bool? idVerified,
    bool? keyIssued,
    String? idDocumentUrl,
    String? signatureUrl,
  }) {
    return CheckIn(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      guestId: guestId ?? this.guestId,
      roomId: roomId ?? this.roomId,
      checkInTime: checkInTime ?? this.checkInTime,
      idVerified: idVerified ?? this.idVerified,
      keyIssued: keyIssued ?? this.keyIssued,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
    );
  }
}
