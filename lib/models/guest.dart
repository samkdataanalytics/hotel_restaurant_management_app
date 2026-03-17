class Guest {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String idType;
  final String idNumber;
  final String nationality;
  final String? passportOrNic;
  final DateTime? dateOfBirth;
  final String? whatsApp;

  Guest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.idType,
    required this.idNumber,
    required this.nationality,
    this.passportOrNic,
    this.dateOfBirth,
    this.whatsApp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'idType': idType,
      'idNumber': idNumber,
      'nationality': nationality,
      'passportOrNic': passportOrNic,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'whatsApp': whatsApp,
    };
  }

  factory Guest.fromMap(Map<String, dynamic> map) {
    return Guest(
      id: map['id'] as String,
      fullName: map['fullName'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      idType: map['idType'] as String,
      idNumber: map['idNumber'] as String,
      nationality: map['nationality'] as String,
      passportOrNic: map['passportOrNic'] as String?,
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.parse(map['dateOfBirth'] as String) : null,
      whatsApp: map['whatsApp'] as String?,
    );
  }

  Guest copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? idType,
    String? idNumber,
    String? nationality,
    String? passportOrNic,
    DateTime? dateOfBirth,
    String? whatsApp,
  }) {
    return Guest(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      nationality: nationality ?? this.nationality,
      passportOrNic: passportOrNic ?? this.passportOrNic,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      whatsApp: whatsApp ?? this.whatsApp,
    );
  }
}

